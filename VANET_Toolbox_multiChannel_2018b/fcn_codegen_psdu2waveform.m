txAddr=1;
rxAddr=1;
frameBody=zeros(1,800);


fileName=strcat('phy_psdu2waveform_ack_mex.',mexext);
if exist(fileName,'file')==0
    disp('<phy_psdu2waveform_ack_mex> not detected, generating.');
    codegen phy_psdu2waveform_ack -args {txAddr}
end

fileName=strcat('phy_psdu2waveform_data_mex.',mexext);
if exist(fileName,'file')==0
    disp('<phy_psdu2waveform_data_mex> not detected, generating.');
    codegen phy_psdu2waveform_data -args {txAddr,rxAddr,frameBody}
end

