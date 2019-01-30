# vanet_toolbox
Vehicular Network Simulator in MATLAB/Simulink Environment based on Discrete-event System.  # vanet_toolbox
Vehicular Network Simulator in MATLAB/Simulink Environment based on Discrete-event System.  
Note:

1. The 1st time running may take several minutes to initiate. It is normal, as MATLAB/Simulink is performing C code generation in order to accelerate the execution speed. Once the code generation is finished, the Simulink model or library will open, and next time it won't take too much time.

2. VANET_Toolbox r2018a will be removed in future release.

The vehicular network simulator, VANET toolbox, is a Simulink library. The library contains major vehicular network layers, APP layer, MAC layer, and the PHY layer.

APP layer is responsible for message generation and vehicular mobility models. Currently, APP layer generates messages including Basic Safety Message (BSM) and Lane Changing Message. The mobility models include the car-following model (CFM) and lane-changing model (LCM), thus users can simulate braking and changing lane behaviors.

MAC layer implemented Enhanced Distributed Channel Access (EDCA) according to IEEE 802.11p. The messages entity 0from APP layer is converted into frame entity, experience channel contention period and sent to PHY layer as waveform entity. On the other hand, the waveform received from the PHY layer is converted into payload and sent to the APP layer. The MAC layer also supports Relible Data Transmission (RDT), i.e., DATA-ACK.

PHY layer includes a two-ray ground reflection model and an AWGN channel based on WAVE/DSRC standards. The Tx/Rx and AWGN are developed based on IEEE 802.11a and implemented by WLAN system toolbox.

VANET library also includes a vehicular object, which consists APP, MAC and PHY layer. In order to simulate V2V communication, users should include at least two 'vehicle' blocks, a 'channel' block and a 'control panel' block. Some Simulink demos are provided.

VANET toolbox provides a basic GUI for users to conduct simulations in batches. To open the GUI, type 'vanet' in MATLAB command window and tune up the necessary parameters.

GUI only has limited options, while the Simulink model is limited in a large-scale simulation. In order to simulate with all tunable parameters in large scale, simulations need to be created by MATLAB script. Please refer to 'simLC.m' for more details.

https://www.youtube.com/watch?v=wIohwbSk68I



The required MathWorks Products includes: 
MATLAB; 
MATLAB Coder; 
Simulink; 
Simulink Coder; 
SimEvents Toolbox; 
WLAN System Toolbox; 
Communications System Toolbox; 
DSP System Toolbox.



