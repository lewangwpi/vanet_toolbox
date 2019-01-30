function [waveform,psduLength] = phy_psdu2waveform( varargin )

%   varargin:
    %   varargin{1}-> Data(0) 
        %   varargin{2}-> TA
        %   varargin{3}-> RA
        %   varargin{4}-> Data payload;  ACK has no payload
    % varargin{1}-> ACK(1)
        %varargin{2}-> TA, tell TA packet is delivered;
        %varargin{3}-> Sequence number, currently using BUS, should change
        %in the future
        
        
        
    switch varargin{1}
        case 0  %data
            payload=de2bi(varargin{4});
            inframe=macFrame();        
            inframe.typeField=macFrame.DATATYPE;
            inframe.data=reshape(payload',[1,numel(payload)]);
            inframe.address1Field=varargin{2};  % Transmitter Address (TA)
            inframe.address3Field=varargin{3};  % Receiver Address (RA)

        case 1  %ACK
            inframe=macFrame();        
            inframe.address1Field=varargin{2};  % ACK only has Reciever Address (RA)         
    end       
    
    cbw = 'CBW10';
    % Create a format configuration object for a SISO nonHT transmission
    cfgnonHT = wlanNonHTConfig();
    cfgnonHT.NumTransmitAntennas = 1;    % 1 transmit antennas 
    cfgnonHT.ChannelBandwidth = cbw;
    psduLength = floor(numel(inframe.frameArray)/8); % the PSDU is in bytes and the frameArray are bits
    cfgnonHT.PSDULength=psduLength; 
    waveform = wlanWaveformGenerator(double(inframe.frameArray),cfgnonHT);

    % Add trailing zeros to allow for channel filter delay
    waveform = [waveform; zeros(15,cfgnonHT.NumTransmitAntennas)];
    
end

