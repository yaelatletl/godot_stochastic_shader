#include <Godot.hpp>
#include <math.h>
#include <Reference.hpp>
#define PI 3.141592

using namespace godot;


class AdvancedMath : public Reference {
    GODOT_CLASS(AdvancedMath, Reference);
public:
    AdvancedMath() { }

    /* _init must exist as it is called by Godot */
    void _init() { }

    Variant inverf(float x) const
    {
       float tt1, tt2, lnx, sgn;
       sgn = (x < 0) ? -1.0f : 1.0f;

       x = (1 - x)*(1 + x);        // x = 1 - x*x;
       lnx = logf(x);

       tt1 = 2/(PI*0.147) + 0.5f * lnx;
       tt2 = 1/(0.147) * lnx;

       return(sgn*sqrtf(-tt1 + sqrtf(tt1*tt1 - tt2)));
    }

    Variant erf(float in) const
    {
    	return erf(in);
    }

    static void _register_methods() {
        register_method("erf", &AdvancedMath::erf);
        register_method("inverf", &AdvancedMath::inverf);
        /**
         * How to register exports like gdscript
         * export var _name = "SimpleClass"
         **/
        register_property<AdvancedMath, String>("base/name", &AdvancedMath::_name, String("AdvancedMath"));


    }
    String _name;
};
