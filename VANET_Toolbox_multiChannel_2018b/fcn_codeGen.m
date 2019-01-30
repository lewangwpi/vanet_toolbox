SNR=40;
nVar = 10^(-SNR/10);
cbw='CBW10';  
payloadlength=800;
wsmp=ones(1,payloadlength);
index=1;

%% Code Generate app_wsmp2msg
disp(' ');
disp('Checking app_wsmp2msg_mex...');

mesFileName=strcat('app_wsmp2msg_mex.',mexext);
if exist(mesFileName,'file')==0
    disp([mesFileName ' not found, code generating it.']);
    codegen app_wsmp2msg.m -args {wsmp,index} -report;
    
end

%% Code Generate phy_waveform2psdu_data
disp(' ');
disp('Checking phy_waveform2psdu_data_mex');
detectFileName=strcat('phy_channelpacketDetection_data_mex.',mexext);
receptFileName=strcat('phy_packetReception_noOffset_data_mex.',mexext);

if exist(detectFileName,'file' )==0 || exist(receptFileName,'file')==0 
    disp('phy_waveform2psdu_data_mex not found.');
    [inWaveform,PSDULength]=phy_psdu2waveform(0,0,0,wsmp);  
    [pktOffset,cfgnonHT,outWaveform]  = phy_channelpacketDetection_data(inWaveform,SNR,PSDULength);
    
    if exist(detectFileName,'file' )==0
        disp(['  - code generating ' detectFileName]);
        codegen phy_channelpacketDetection_data -args {inWaveform,SNR,PSDULength} -report;
    end
    
    if exist(receptFileName,'file')==0
        disp(['  - code generating ' receptFileName]);
        codegen phy_packetReception_noOffset_data -args {outWaveform,cfgnonHT,cbw,nVar} -report;
    end
    
end

% 
% %test
% vehicleID=777;
% txAddr=22;
% dstAddress=33;
% SNR=40;
% payloadlength=800;
% wsmp=ones(1,payloadlength);
% wsmp=app_msg2wsmp(vehicleID,wsmp,2);
% txPayloadBuffer=wsmp;
% frameBody=txPayloadBuffer;   
% frameBodyBuffer=frameBody;
% [waveform,waveformLength]=phy_psdu2waveform(0,txAddr,dstAddress,frameBodyBuffer);   
% [ status, outframe, outmsg, type, subtype ] = phy_waveform2psdu_data( waveform,SNR,waveformLength );
% wsmp=outframe;
% vehicleID=app_wsmp2msg(wsmp,2);  
% vehicleID

%% Code Generate phy_waveform2psdu_ack
disp(' ');
disp('Checking phy_waveform2psdu_ack_mex');
detectFileName=strcat('phy_channelpacketDetection_ack_mex.',mexext);
receptFileName=strcat('phy_packetReception_noOffset_ack_mex.',mexext);

if exist(detectFileName,'file')==0 || exist(receptFileName,'file')==0
    disp('phy_waveform2psdu_ack_mex not found.');
    [ackBody,length]=phy_psdu2waveform(1,1);    
    [pktOffset,cfgnonHT,outWaveform]  = phy_channelpacketDetection_ack(ackBody,SNR,length);
    if exist(detectFileName,'file')==0 
        disp(['  - code generating ' detectFileName ]);
        codegen phy_channelpacketDetection_ack -args {ackBody,SNR,length} -report;
    end

    if exist(receptFileName,'file')==0
        disp([ '  - code generating ' receptFileName]);
        codegen phy_packetReception_noOffset_ack -args {outWaveform,cfgnonHT,cbw,nVar} -report; 
    end
end

% % test
% [a,b,c,d,e]=phy_waveform2psdu_ack(ackBody,SNR,length);
% 


%% Codegen phy_psdu2waveform
disp(' ');
disp('Checking phy_psdu2waveform...');
txAddr=1;
rxAddr=1;
frameBody=zeros(1,800);

fileName=strcat('phy_psdu2waveform_ack_mex.',mexext);
if exist(fileName,'file')==0
    disp(['  - ', fileName, ' not detected, generating.']);
    codegen phy_psdu2waveform_ack -args {txAddr} -report;
end

fileName=strcat('phy_psdu2waveform_data_mex.',mexext);
if exist(fileName,'file')==0
    disp(['  - ', fileName, ' not detected, generating.']);
    codegen phy_psdu2waveform_data -args {txAddr,rxAddr,frameBody} -report;
end







