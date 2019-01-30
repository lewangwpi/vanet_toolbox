function [ status, outframe, outmsg, type, subtype ] = phy_waveform2psdu_ack( inWaveform,snr,PSDULength )
    nVar = 10^(-snr/10);
        cbw='CBW10';  
[pktOffset,cfgnonHT,outWaveform]  = phy_channelpacketDetection_ack_mex(inWaveform,snr,PSDULength);
    if isempty(pktOffset) % If empty no L-STF detected; packet error
        disp('nullOffset ACK')
        status = 0;
        outframe = zeros(1,800);
        outmsg='NO LTF1';
        type=double(0);
        subtype=double(0);
        return
    elseif pktOffset == 0
%         disp('zeroOffset ACK')
%         [ status, outframe, outmsg, type, subtype ]= phy_waveform2psdu_ack_original(inWaveform,snr,PSDULength);
%         size(outframe);
%         [ status, outframe, outmsg, type, subtype ]= phy_packetReception_noOffset(outWaveform,cfgnonHT,cbw,nVar);
%         size(outframe);
       [ status, outframe, outmsg, type, subtype ]= phy_packetReception_noOffset_ack_mex(outWaveform,cfgnonHT,cbw,nVar);
%        size(outframe);
       
    
    else
        disp('NonzeroOffset ACK')
        [ status, outframe, outmsg, type, subtype ]= phy_waveform2psdu_ack_original(outWaveform,cfgnonHT,cbw,nVar);
    end
    
    
    
    

end

