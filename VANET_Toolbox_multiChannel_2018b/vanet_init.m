%   set_param(gcb,'StopFcn','my_stop_fcn')
function vanet_init( )
    if exist('results','dir')==0
        mkdir('results');
    end
%     assignin('base','road','crossRD');
%     assignin('base','road','highway');
    assignin('base','V2Xmode','V2V');

    payloadlength=800;
    assignin('base','payloadLength',payloadlength);

    [waveform,~]=phy_psdu2waveform(0,0,0,ones(1,payloadlength));
    waveformLength=length(waveform);
    assignin('base','waveformLength',waveformLength);
    
    %% Create Payload Bus
    Payload=Simulink.Bus;    
    payload1=Simulink.BusElement;    
    payload1.Name='wsmp';  
    payload1.Dimensions=[1,payloadlength];        
    payload2=Simulink.BusElement;
    payload2.Name='priority';
    payload2.Dimensions=[1,1];  
    payload3=Simulink.BusElement;
    payload3.Name='VehicleID';
    payload4=Simulink.BusElement;
    payload4.Name='pos';
    payload4.Dimensions=[1,2];
    payload5=Simulink.BusElement;
    payload5.Name='dstAddress';
    payload6=Simulink.BusElement;
    payload6.Name='channelNum';
    Payload.Elements=[payload1,payload2,payload3,payload4,payload5,payload6];  
    clear payload1 payload2 payload3 payload4 payload5 payload6;
    
    %% Create Frame bus
    Frame=Simulink.Bus;
    frame1=Simulink.BusElement;
    frame1.Name='Duration';
    frame2=Simulink.BusElement;    
    frame2.Name='Body';    
    frame2.Dimensions=[1 payloadlength];    
    frame3=Simulink.BusElement;
    frame3.Name='SN';      
    frame4=Simulink.BusElement;
    frame4.Name='ACTag';    
    frame5=Simulink.BusElement;
    frame5.Name='Retry';
    frame6=Simulink.BusElement;
    frame6.Name='Address1';
    frame7=Simulink.BusElement;
    frame7.Name='Address2';
    frame8=Simulink.BusElement;
    frame8.Name='Address3';
    frame9=Simulink.BusElement;
    frame9.Name='ToDS';
    frame10=Simulink.BusElement;
    frame10.Name='FromDS';
    frame11=Simulink.BusElement;
    frame11.Name='Timestamp';
    frame12=Simulink.BusElement;
    frame12.Name='dstAddress';
    frame13=Simulink.BusElement;
    frame13.Name='channelNum';
    Frame.Elements=[frame1,frame2,frame3,frame4,frame5,frame6,frame7,frame8,frame9,frame10,frame11,frame12,frame13];
    clear frame1 frame2 frame3 frame4 frame5 frame6 frame7 frame8 frame9 frame10 frame11 frame12 frame13;

    %% Creat Waveform bus
    Waveform=Simulink.Bus;
    waveform1=Simulink.BusElement;
    waveform1.Name='SN';
    waveform2=Simulink.BusElement; % Waveform.data.Control: Only used to display 'data or ack is transmitting'. Delete won't affect the model;
    waveform2.Name='Control';
    waveform3=Simulink.BusElement;    
    waveform3.Name='Body';    
    waveform3.Dimensions=[waveformLength,1];    
    waveform3.Complexity='complex';
    waveform4=Simulink.BusElement;
    waveform4.Name='Length';  % PSDU Length    
    waveform5=Simulink.BusElement;
    waveform5.Name='ACKBody';    % Data body and ACK body has different length, in the bus, have to define two elements coresponding to each 
    waveform5.Dimensions=[975 1];
    waveform5.Complexity='complex';
    waveform6=Simulink.BusElement;
    waveform6.Name='SNR';        
    waveform7=Simulink.BusElement;    
    waveform7.Name='ACTag';    
    waveform8=Simulink.BusElement;
    waveform8.Name='FromDS';
    waveform9=Simulink.BusElement;
    waveform9.Name='ToDS';
    waveform10=Simulink.BusElement;
    waveform10.Name='Address1';     % Address 1
    waveform11=Simulink.BusElement;
    waveform11.Name='Address2';     
    waveform12=Simulink.BusElement;
    waveform12.Name='Address3';     
    waveform13=Simulink.BusElement;
    waveform13.Name='Retry';
    waveform14=Simulink.BusElement;
    waveform14.Name='Timestamp';
    waveform15=Simulink.BusElement;
    waveform15.Name='pos';
    waveform15.Dimensions=[1,2];
    waveform16=Simulink.BusElement;
    waveform16.Name='channelNum';
    
    Waveform.Elements=[waveform1,waveform2,waveform3,waveform4,waveform5,waveform6,waveform7,waveform8,waveform9,waveform10 waveform11 waveform12 waveform13 waveform14 waveform15 waveform16];
    clear waveform1 waveform2 waveform3 waveform4 waveform5 waveform6 waveform7 waveform8 waveform9 waveform10 waveform11 waveform12 waveform13 waveform14 waveform15 waveform16;
    
    mgmFrame = Simulink.Bus;
    mgm1 = Simulink.BusElement;
    mgm1.Name = 'type';
    mgm2 = Simulink.BusElement;
    mgm2.Name = 'field1';
    mgm3 = Simulink.BusElement;
    mgm3.Name = 'field2';
    mgm3.Dimensions = [1,6];
    mgmFrame.Elements = [mgm1,mgm2,mgm3];
    clear mgm1 mgm2 mgm3;
    
    %Mac frame used for all other OBU
    currentPacket = macFrame();                 
    assignin('base','mgmFrame', mgmFrame);
    assignin('base','Frame',Frame);
    assignin('base','Payload',Payload);
    assignin('base','Waveform',Waveform);
    assignin('base','currentPacket',currentPacket);
    
    %% Initiate functions
%     fcn_carGlobalDB('init');  
%     fcn_carLocalDB('init');
% %     simTime=30;
%     if exist('simTime','var')                           
%         simTime=evalin('base','simTime');
%     else
%         simTime=30;
%     end
% 
%     numVehicles=evalin('base','numStations');
%     fcn_CAVrecord('init',numVehicles,simTime);                    
    
    %%
%     % Microsoft Windows
%     addpath(genpath([pwd '\vanet_Mask\']));
%     addpath(genpath([pwd '\vanet_MAC\']));
%     addpath(genpath([pwd '\vanet_PHY\']));
%     
%     % OSX 
%     addpath(genpath([pwd '/vanet_Mask/'])); 
%     addpath(genpath([pwd '/vanet_MAC/']));
%     addpath(genpath([pwd '/vanet_PHY/']));

    fcn_codeGen
%     fcn_codegen_psdu2waveform
%     fcn_codeGen_wsmp2msg
end

