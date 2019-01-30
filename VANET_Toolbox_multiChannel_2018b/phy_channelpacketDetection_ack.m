function [pktOffset,cfgnonHT,outWaveform] = phy_channelpacketDetection_ack(inWaveform,snr,PSDULength)
%UNTITLED Add snr defined for the AWGN channel and try to make the packet
%detection. 
%   Detailed explanation goes here
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
%     fs=10000000; % for the purpose of code gen
    

%     PFO = comm.PhaseFrequencyOffset;
%     PFO.SampleRate = 10000000;
%     PFO.PhaseOffset = 0;
%     PFO.FrequencyOffsetSource = 'Input port';
    pktOffset = wlanPacketDetect(outWaveform,cbw);
end

