function [waveform,PSDULength] = phy_psdu2waveform_ack(txAddress)

    inframe=macFrame();        
    inframe.address1Field=txAddress;  % ACK only has Reciever Address (RA)    
    
    cbw = 'CBW10';
    % Create a format configuration object for a SISO nonHT transmission
    cfgnonHT = wlanNonHTConfig();
    cfgnonHT.NumTransmitAntennas = 1;    % 1 transmit antennas 
    cfgnonHT.ChannelBandwidth = cbw;
    cfgnonHT.PSDULength = floor(numel(inframe.frameArray)/8); % the PSDU is in bytes and the frameArray are bits
    PSDULength=cfgnonHT.PSDULength; 
    waveform = wlanWaveformGenerator(double(inframe.frameArray),cfgnonHT);

    % Add trailing zeros to allow for channel filter delay
    waveform = [waveform; zeros(15,cfgnonHT.NumTransmitAntennas)];

end