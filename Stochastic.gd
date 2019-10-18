tool
extends ShaderMaterial
onready var Math = GDNative.new()
const GAUSSIAN_AVERAGE = 1.0
const GAUSSIAN_STD = 1.0
signal Tinv_ready
signal TInput_ready

func _run():
	Math.library = preload("res://bin/AvMath.gdnlib")
	Math.initialize()
	var input = get_shader_param("texture_albedo")
	var Tinput = Image.new()
	Tinput.create(input.get_width(), input.get_height(), false, Image.FORMAT_RGB8)
	var Tinv = Image.new()
	Tinv.create(input.get_width(), input.get_height(), false, Image.FORMAT_RGB8)
	Tinv = ComputeinvT(input, Tinv)
	Tinput = ComputeTinput(input, Tinput)
	set_shader_param("texture_albedo_tinv", Tinv)
	set_shader_param("texture_albedo_input", Tinput)

func _ready():
	Math.library = preload("res://bin/AvMath.gdnlib")
	Math.initialize()
	var input = get_shader_param("texture_albedo")
	var Tinput = Image.new()
	Tinput.create(input.get_width(), input.get_height(), false, Image.FORMAT_RGB8)
	var Tinv = Image.new()
	Tinv.create(input.get_width(), input.get_height(), false, Image.FORMAT_RGB8)
	Tinv = ComputeinvT(input, Tinv)
	Tinput = ComputeTinput(input, Tinput)
	set_shader_param("texture_albedo_tinv", Tinv)
	set_shader_param("texture_albedo_input", Tinput)
	
	
func Erf( input : float) -> float:
	var res : float  = Math.call_native("float", "erf", [input])
	return res
	
func ErfInv( input : float) -> float:
	var res : float  = Math.call_native("float", "inverf", [input])
	return res


func CDF ( x:float , mu:float , sigma:float ) -> float:
	var U : float = 0.5 * (1 + Erf ((x - mu ) /( sigma * sqrt(2.0))))
	return U;

func invCDF ( U : float , mu : float , sigma : float ) -> float:
	var x : float = sigma * sqrt (2.0) * ErfInv (2.0*U -1.0) + mu 
	return x
	
func ComputeTinput ( input : Image ,  T_input : Image )-> Image:
	# Sort pixels of example image
	var sortedInputValues:Array ;
	sortedInputValues.resize ( input . width * input . height );
	for y in range(0, input.height):
		for x in range(0, input.width):
			sortedInputValues [ y * input . width + x ]. x = x;
			sortedInputValues [ y * input . width + x ]. y = y;
			sortedInputValues [ y * input . width + x ]. value = input . get_pixel (x , y);

	sortedInputValues.sort();

	for i in range(0, sortedInputValues.size ()):
		var x : int = sortedInputValues [i]. x;
		var y : int = sortedInputValues [i]. y;
	# Input quantile ( given by its order in the sorting )
		var U : float = (i + 0.5 ) / ( sortedInputValues.size () );
	# Gaussian quantile
		var G : float= invCDF (U , GAUSSIAN_AVERAGE , GAUSSIAN_STD );
	# Store
		T_input . set_pixel (x , y , Color(G))
	emit_signal("TInput_ready")
	return T_input
	
func ComputeinvT ( input : Image , Tinv : Image) -> Image:
	# Sort pixels of example image
	var sortedInputValues : Array ;
	sortedInputValues . resize ( input . width * input . height );
	for y in range( 0,  input . height):
		for x in range( 0,  input . width):
			sortedInputValues [y * input . width + x] = input . get_pixel (x , y );
	sortedInputValues.sort()
	for i in range(0 ,  Tinv . width):
# Gaussian value in [0 , 1]
		var G : float = (i + 0.5) / ( Tinv . width );
# Quantile value
		var U : float = CDF (G , GAUSSIAN_AVERAGE , GAUSSIAN_STD ) ;
# Find quantile in sorted pixel values
		var index : int =  floor (U * sortedInputValues . size () );
# Get input value
		var I : float = sortedInputValues [ index ];
# Store in LUT
		Tinv . set_pixel (i , 0 , Color(I) );
	emit_signal("Tinv_ready")
	return Tinv
