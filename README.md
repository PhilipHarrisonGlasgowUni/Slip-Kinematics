# UniaxialBiasExtensionTests-Slip-Kinematics
WHAT IS IT?
A quick and easy-to-use code that illustrates the integrity and cohesion of engineering fabrics. See for example: https://youtu.be/BW7T3RPVYJc 
The code is a MatLab file initially created in 2004 and recently improved with the assistance of Claude using MatLab vR2026b.

WHO'S IT FOR?
It's for composites processing engineers and researchers who want to visualise slip and/or characterise the integrity of engineering fabrics (e.g. woven carbon, glass or kevlar cloth).

WHAT YOU NEED TO RUN IT?
A recent version of MatLab (2026 & onwards).

HOW TO USE
>> Download the MatLab file "UBE_Slip_real_4.m", add to the work path and run.
>> In the interface, press play to see the UBE Slip animation with pre-defined slip kinematics.
>> Toggle the various options on/off to change the animation properties, record the video if you want.
>> You can add your own kinematics to generate different slip behaviour.
>> If you're really keen, you can conduct a uniaxial bias extension test using this experimental protocol (https://dx.doi.org/10.17504/protocols.io.81wgbyy93vpk/v1), measure the slip kinematics and use these in the code. 
>> If you're really, really keen, you could use these kinematics to figure out the internal friction of the fabric as a new research project :-)

For background on the implemented kinematics you can read the conference paper: Harrison, P, Tan, Mk and Long, AC (2005) Kinematics of Intra-Ply Slip in Textile Composites during Bias Extension Tests. In: 8th Int. ESAFORM Conf. on Materials Forming, Cluj-Napoca, Romania

BACKROUND (a modified abstract of the 2005 conference paper)
The Bias Extension test has become one of the preferred methods of characterising the shear behaviour of both dry and pre-impregnated textile composites. Usually, results from these tests are considered useful as long as the textile composite undergoes so-called trellis shear or Pin-Jointed Net (PJN) kinematics. However, further information about the material is available following the breakdown of this kinematic criteria, i.e. when the textile composite undergoes a combination of PJN and intra-ply slip kinematics. Test data produced following the breakdown of the PJN criteria can be used to quantify the general integrity of a given textile. The latter is an indicator of the materials resistance to handling during lay-up and to intraply slip during forming. By measuring the inter-fibre angle and the width of the tested specimen, the deformation within the sample can be described using relatively simple kinematics, even as the sample reaches very high elongations. This computer code to illustrates this deformation. Predictions are compared directly with BE tests performed on a glass / polypropylene 2 x 2 twill weave thermoplastic, though custom kinematics can be easily introduced using the graphical user interface.
