tool
extends MeshInstance
export(Texture) var albedo
onready var MathLib = GDNative.new()
const GAUSSIAN_AVERAGE = 0.5
const GAUSSIAN_STD = 1.0/(6.0*6.0)
signal Tinv_ready
signal TInput_ready

func _ready():
	print("initalizing")
	var mat = get_surface_material(0)
	MathLib.library = preload("res://bin/AdvMath.gdnlib")
	var success = MathLib.initialize()
	print(success)
	var input = mat.get_shader_param("texture_albedo")
	if input == null:
		input = albedo
	var Tinput = Image.new()
	Tinput.create(input.get_width(), input.get_height(), false, Image.FORMAT_RGBAF)
	var Tinv = Image.new()
	Tinv.create(input.get_width(), input.get_height(), false, Image.FORMAT_RGBAF)
	input = input.get_data()
	input.lock()
	Tinv = ComputeinvT(input, Tinv)
	Tinv.save_png("res://tinv.png")
	Tinput = ComputeTinput(input, Tinput)
	
	Tinput.save_png("res://tinput.png")
	mat.set_shader_param("texture_albedo_tinv", Tinv)
	mat.set_shader_param("texture_albedo_input", Tinput)
	

	
	
func Erf( input : float) -> float:
#	var res : float  = MathLib.call_native("float", "erf", [input])
	var res = erf(input)
	
	return res
	
func ErfInv( input : float) -> float:
#	var res : float  = MathLib.call_native("float", "inverf", [input])
	var res = inverf(input)
	
	return res


func CDF ( x:float , mu:float , sigma:float ) -> float:
	var U : float = 0.5 * (1 + Erf ((x - mu ) /( sigma * sqrt(2.0))))
	return U;

func invCDF ( U : float , mu : float , sigma : float ) -> float:
	var x : float = sigma * sqrt (2.0) * ErfInv (2.0*U -1.0) + mu 
	return x

class Sorter:
	static func sort(a, b):
		if a.y < b.x:
			return true
		return false

func ComputeTinput ( input : Image ,  T_input : Image )-> Image:
	print("Enter Tinput computation")
	T_input.lock()
	# Sort pixels of example image
	var sortedInputValues: Array 
	var OutputColors : PoolVector3Array
	
	sortedInputValues.resize ( input . get_width() * input . get_height() )
	OutputColors.resize(sortedInputValues.size())
	input.lock()
	
	for y in range(0, input.get_height()):
		for x in range(0, input.get_width()):
				sortedInputValues [ y * input . get_width() + x ] =  Vector3(
				x, 
				y,
				input . get_pixel (x , y).to_rgba32())
	var sortedR = sortedInputValues.duplicate(true)
	var sortedG = sortedInputValues.duplicate(true)
	var sortedB = sortedInputValues.duplicate(true)
	
	for i in range(0,sortedInputValues.size()):
		sortedR[i].z = Color(int(sortedR[i].z)).r
		sortedG[i].z = Color(int(sortedG[i].z)).g
		sortedB[i].z = Color(int(sortedB[i].z)).b
		
	sortedR.sort()#_custom(Sorter, "sort")
	sortedG.sort()#_custom(Sorter, "sort")
	sortedB.sort()
	
	for channels in range(0,2):
		for i in range(0, sortedInputValues.size ()):
			var x : int
			var y : int
			match channels:
				0:
					x = sortedR [i]. x;
					y = sortedR [i]. y;
				1:
					x = sortedG [i]. x;
					y = sortedG [i]. y;
				2:
					x = sortedB [i]. x;
					y = sortedB [i]. y;
	# Input quantile ( given by its order in the sorting )
			var U : float = (i + 0.5 ) / ( sortedInputValues.size () );
	# Gaussian quantile
			var G : float= invCDF (U , GAUSSIAN_AVERAGE , GAUSSIAN_STD );
	# Store
			match channels:
				0:
					OutputColors[i].x = G
				1:
					OutputColors[i].y = G
				2:
					OutputColors[i].z = G
	for i in range(0,OutputColors.size()):
		var x : int = sortedInputValues [i]. x;
		var y : int = sortedInputValues [i]. y;
		T_input . set_pixel (x , y , Color(OutputColors[i].x,OutputColors[i].y, OutputColors[i].z))
	emit_signal("TInput_ready")
	return T_input
	
func ComputeinvT ( input : Image , Tinv : Image) -> Image:
	print("Enter Tinv computation")
	var output : Image = Image.new()
	
	# Sort pixels of example image
	
	var sortedInputValues : Array ;
	sortedInputValues . resize ( input.get_width() * input .get_height() )
	output.create(16384,1,false,Image.FORMAT_RGBF)
	output.lock()
	input.lock()
	for y in range( 0,  input . get_height()):
		for x in range( 0,  input . get_width()):
			sortedInputValues [y * input . get_width() + x] = input . get_pixel (x , y ).to_rgba32();
	
	var sortedR = sortedInputValues.duplicate(true)
	var sortedG = sortedInputValues.duplicate(true)
	var sortedB = sortedInputValues.duplicate(true)
	
	for i in range(0,sortedInputValues.size()):
		sortedR[i] = Color(int(sortedInputValues[i])).r
		sortedG[i] = Color(int(sortedInputValues[i])).g
		sortedB[i] = Color(int(sortedInputValues[i])).b
		
	sortedR.sort()#_custom(Sorter, "sort")
	sortedG.sort()#_custom(Sorter, "sort")
	sortedB.sort()
	for i in range(0 ,  output . get_width()):
# Gaussian value in [0 , 1]
		var G : float = (i + 0.5) / ( output . get_width() );
# Quantile value
		var U : float = CDF (G , GAUSSIAN_AVERAGE , GAUSSIAN_STD ) ;
# Find quantile in sorted pixel values
		var index : int =  floor (U * (sortedInputValues . size () -1));
# Get input value
		
		var IR : float = sortedR[index]
		var IG : float = sortedG[index]
		var IB : float = sortedB[index]
		
# Store in LUT
		output . set_pixel (i , 0 , Color(IR,IG,IB));
	emit_signal("Tinv_ready")
	return output
