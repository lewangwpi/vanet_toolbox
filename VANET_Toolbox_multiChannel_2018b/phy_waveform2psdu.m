function [ status, outframe, outmsg, type, subtype ] = phy_waveform2psdu( inWaveform,snr,PSDULength )
    nVar = 10^(-snr/10);
    cbw='CBW10';                                     
    % Noise variance after OFDM demodulation. Scale SNR by the number of
    % space-time streams and account for scaling during demodulation.
    % Create a format configuration object for a SISO nonHT transmission
    cfgnonHT = wlanNonHTConfig();
    cfgnonHT.NumTransmitAntennas = 1;    % 1 transmit antennas
    cfgnonHT.ChannelBandwidth = cbw;
    cfgnonHT.PSDULength=PSDULength;
    NumReceiveAntennas=1;
    
    %% AWGN Channel   
    % Get the number of occupied subcarriers and FFT length
    [data,pilots] = helperSubcarrierIndices(cfgnonHT,'HT');
    Nst = numel(data)+numel(pilots); % Number of occupied subcarriers
    Nfft = helperFFTLength(cfgnonHT);      % FFT length
    % Create an instance of the AWGN channel per SNR point simulated
    AWGN = comm.AWGNChannel;
    AWGN.NoiseMethod = 'Signal to noise ratio (SNR)';
    AWGN.SignalPower = 1/NumReceiveAntennas; % Normalization
    AWGN.SNR = snr-10*log10(Nfft/Nst); % Account for energy in nulls
    outWaveform = step(AWGN,inWaveform); % Add noise                            
    %% Rx: Estimation
    % Get the baseband sampling rate    
    fs = wlanSampleRate(cfgnonHT);
    % Indices for accessing each field within the time-domain packet
    ind = wlanFieldIndices(cfgnonHT);
    % Create an instance of the frequency impairment object
    PFO = comm.PhaseFrequencyOffset;
    PFO.SampleRate = fs;
    PFO.PhaseOffset = 0;
    PFO.FrequencyOffsetSource = 'Input port';
    pktOffset = wlanPacketDetect(outWaveform,cbw);
    if isempty(pktOffset) % If empty no L-STF detected; packet error
        status = 0;
        outframe = zeros(1,800);
        outmsg='NO LTF1';
        type=double(0);
        subtype=double(0);
        return
    end
    % Extract L-STF and perform coarse frequency offset correction
    lstf = outWaveform(pktOffset+(ind.LSTF(1):ind.LSTF(2)),:);
    coarseFreqOff = wlanCoarseCFOEstimate(lstf,cbw);
    outWaveform = step(PFO,outWaveform,-coarseFreqOff);
    release(PFO); % Release object for subsequent processing
    % Extract the Non-HT fields and determine start of L-LTF
    nonhtfields = outWaveform(pktOffset+(ind.LSTF(1):ind.LSIG(2)),:);
    lltfIdx = wlanSymbolTimingEstimate(nonhtfields,cbw);
    % Synchronize the received outWaveform given the offset between the
    % expected start of the L-LTF and actual start of L-LTF
    pktOffset = pktOffset+lltfIdx; 
    % If no L-LTF detected or if packet detected outwith the range of
    % expected delays from the channel modeling; packet error
    if isempty(lltfIdx) || pktOffset<0 || pktOffset>15
        status = 0;
        outframe = zeros(1,800);
        outmsg = 'NO LTF-';
        type=double(0);
        subtype=double(0);
        return
    end
    outWaveform = outWaveform(1+pktOffset:end,:);
    % Extract L-LTF and perform fine frequency offset correction
    lltf = outWaveform(ind.LLTF(1):ind.LLTF(2),:);
    fineFreqOff = wlanFineCFOEstimate(lltf,cbw);
    outWaveform = step(PFO,outWaveform,-fineFreqOff);
    release(PFO); % Release object for subsequent processing

    % Extract LLTF samples from the outWaveform, demodulate and perform
    % channel estimation
    ltltfDemod = wlanLLTFDemodulate(lltf,cfgnonHT);
    chanEst = wlanLLTFChannelEstimate(ltltfDemod,cfgnonHT);
    %% Rx: Recover and Decode
    % Recover the transmitted PSDU in nonHT Data
    % Extract nonHT Data samples from the outWaveform and recover the PSDU
    
    nonhtdata = outWaveform(ind.NonHTData(1):end,:);
    rxPSDU = wlanNonHTDataRecover(nonhtdata,chanEst,nVar,cfgnonHT);
    
    
    currentPacket = evalin('base','currentPacket');    
    [status, msg] = currentPacket.decodeArray(logical(rxPSDU));

    if status    
        type=double(currentPacket.typeField);
        subtype=double(currentPacket.subtypeField);
        outframe=double(currentPacket.data);
        outmsg = msg;
    else
        outframe = zeros(1,800);
        outmsg = msg;
        type=double(0);
        subtype=double(0);
    end

end

