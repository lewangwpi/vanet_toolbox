function [ status, outframe, outmsg, type, subtype ] = phy_waveform2psdu_data( inWaveform,snr,PSDULength )
    nVar = 10^(-snr/10);
    cbw='CBW10';  
    [pktOffset,cfgnonHT,outWaveform]  = phy_channelpacketDetection_data_mex(inWaveform,snr,PSDULength);
    if isempty(pktOffset) % If empty no L-STF detected; packet error
%         disp('empty pktOffset');
        status = 0;
        outframe = zeros(1,800);
        outmsg='NO LTF1';
        type=double(0);
        subtype=double(0);
        return
    elseif pktOffset == 0
%         disp('zero pktOffset data');
%         [ status, outframe, outmsg, type, subtype ]= phy_waveform2psdu_data_original(inWaveform,snr,PSDULength);
%         size(outframe)
%         [ status, outframe, outmsg, type, subtype ]= phy_packetReception_noOffset_data(outWaveform,cfgnonHT,cbw,nVar);
%         size(outframe)
       [ status, outframe, outmsg, type, subtype ]= phy_packetReception_noOffset_data_mex(outWaveform,cfgnonHT,cbw,nVar);
%        size(outframe)
    else
%         disp('nonZero pktOffset data');
       [status, outframe, outmsg, type, subtype ] = phy_waveform2psdu_data_original(inWaveform,snr,PSDULength ); 
    end
end