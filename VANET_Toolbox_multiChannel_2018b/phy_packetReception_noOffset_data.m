function [status, outframe, outmsg, type, subtype] = phy_packetReception_noOffset_data(outWaveform,cfgnonHT,cbw,nVar)
%UNTITLED2 packet reception without offset

% Extract L-STF and perform coarse frequency offset correction

% Indices for accessing each field within the time-domain packet
ind = wlanFieldIndices(cfgnonHT);
% Create an instance of the frequency impairment object
PFO = comm.PhaseFrequencyOffset('SampleRate',10000000,'PhaseOffset',0,'FrequencyOffsetSource','Input port');

lstf = outWaveform((ind.LSTF(1):ind.LSTF(2)),:);
coarseFreqOff = wlanCoarseCFOEstimate(lstf,cbw);
outWaveform = step(PFO,outWaveform,-coarseFreqOff);

% Extract the Non-HT fields and determine start of L-LTF
nonhtfields = outWaveform(double(ind.LSTF(1):ind.LSIG(2)),:);

lltfIdx = wlanSymbolTimingEstimate(nonhtfields,cbw);
% Synchronize the received outWaveform given the offset between the
% expected start of the L-LTF and actual start of L-LTF



% If no L-LTF detected or if packet detected outwith the range of
% expected delays from the channel modeling; packet error
if isempty(lltfIdx)
    status = 0;
    outframe = zeros(1,800);
    outmsg = 'NO LTF-';
    type=double(0);
    subtype=double(0);
    return
end

if lltfIdx == 0

    outWaveform = outWaveform(1:end,:);
else
    start=1+lltfIdx;
    outWaveform = outWaveform(1:end,:);
end


%this start is wrong, need to sum the offset;


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

% coder.extrinsic('evalin');
currentPacket = macFrame();
%     currentPacket = evalin('base','currentPacket');
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

