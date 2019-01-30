classdef des_MAC_OBU< matlab.DiscreteEventSystem & matlab.system.mixin.Propagates & matlab.system.mixin.SampleTime      
    properties   %Tunable properties
        Retry_MAX=3;  %Retransmision Times (3-8)
        
        % EDCA Parameters 
        
        AIFSN_AC0=9 % AIFSN_AC0
        AIFSN_AC1=6 % AIFSN_AC1
        AIFSN_AC2=3 % AIFSN_AC2
        AIFSN_AC3=2 % AIFSN_AC3
        
        aCWmin=15      
        aCWmax=1023
                
        slottime=13 % Timeslot period (unit:s)
        sifs=32;         
        txAddr=0; % Transmitter Address (txAddr)                
        infraAddress=0; % Infrastructure BSSID        
%         broadcast=0; % Broadcast Option: 0 - off; 1 - on;                
    end
%     properties(DiscreteState)
%         
%         txPayloadPriority  % buffer payload priority
%                 
%         frameTIDFieldBuffer  % Buffer TIDField
%         frameSNBuffer        % Buffer SN        
%         frameRetryBuffer
%                 
%         intContention  % 0 is free                
%                
%     end        
    properties(Access = private) 
        txPayloadPriority  % buffer payload priority
                
        frameTIDFieldBuffer  % Buffer TIDField
        frameSNBuffer        % Buffer SN        
        frameRetryBuffer
                
        intContention  % 0 is free      
        % Contention Window, CWmin,CWmax, for each priority queue
        CWmin_AC0
        CWmax_AC0
        CWmin_AC1
        CWmax_AC1
        CWmin_AC2
        CWmax_AC2
        CWmin_AC3
        CWmax_AC3
        
        % backoff unit: TimeSlot
        % Calculated from [0 CWmin]
        backoff_AC0 
        backoff_AC1
        backoff_AC2
        backoff_AC3
        
        
        % Arbitrary Inter-Frame Space: Calculated from AIFSN
        AIFS_AC0
        AIFS_AC1
        AIFS_AC2
        AIFS_AC3
              
        % Record the transmission/retransmission times of the frames in
        % each AC; If more than 3 transmissions, discard frames.
        txNum_AC0
        txNum_AC1
        txNum_AC2
        txNum_AC3
        
        
        numFrame_AC0   % frame counter for AC0 
        numFrame_AC1
        numFrame_AC2
        numFrame_AC3
       
        propTime=3; % Air prop time: (unit: us)                
        payloadCounter   %Count how many payload enters storage 1
        numRx % number of waveforms received 
        RxDataSN % Squence Number of received data
        RxACKSN  % Squence Number of received ACK
        
        TxACTag % AC tag of Tx data
%         RxACTag % AC tag of Rx data
        
        dataTxDelay                
        dataRxDelay
        
        ackTxRxDelay
        
        ackTimeout %2 propTime + 1 SIFS + ACK transTime, i.e.,  length of ACK/bitrate in Mbps          
        waitForACK  % Squence Number (SN) of packets waiting for an ACK
        srcAddress  % Source address buffer when receiving a single cast packet
        dstAddress
        
        txType
        
        timestampBuffer
               
        V2Xmode

        
        backoffPause
                
        payloadLength
        waveformLength
        
        rxPayloadBuffer        
        txPayloadBuffer    % buffer payload 
        frameBodyBuffer      % Buffer data body
        payloadPosBuffer
        
        SIFS
        EIFS
        slotTime
        rxCRCerr
        
        txPower
        
        txtEnable        
        PLCA=0;
        
        brakeMode='ConLaneChange';
        
    end

    methods(Access = protected)
        %% setup properties
        function setupImpl(obj)
            coder.extrinsic('evalin');
            coder.extrinsic('rng');
            rng('shuffle')
            obj.SIFS=obj.sifs/1000000;
            obj.slotTime=obj.slottime/1000000;
            
            % evalin create error in code generation, hard code temporarily            
            obj.payloadLength=800;
            obj.waveformLength=3935;
            
            obj.rxPayloadBuffer=zeros(1,800);
            obj.txPayloadBuffer=zeros(1,800);
            obj.txPayloadPriority=0;
            obj.payloadCounter=0;
            
            obj.frameBodyBuffer=zeros(1,800);
            obj.frameSNBuffer=0;            
            obj.numRx=0;
            
            %numFrame indicates how many frames stored in each AC, should
            %be replaced by iterateImpl() input parameter. 
            obj.numFrame_AC0=0;
            obj.numFrame_AC1=0;
            obj.numFrame_AC2=0;
            obj.numFrame_AC3=0;
            
            %Define Contention Window (min, max) for Backoff Process
            obj.CWmin_AC0=obj.aCWmin;
            obj.CWmax_AC0=obj.aCWmax;
            
            obj.CWmin_AC1=obj.aCWmin;
            obj.CWmax_AC1=obj.aCWmax;
            
            % 13us one slot time
            
            obj.CWmin_AC2=(obj.aCWmin+1)/2-1; % 0-7
            obj.CWmax_AC2=obj.aCWmin;       % 0-15
            
            obj.CWmin_AC3=(obj.aCWmin+1)/4-1; % 0-3
            obj.CWmax_AC3=(obj.aCWmin+1)/2-1; % 0-7
            
            %Backoff timer for each AC
            obj.backoff_AC0=0;
            obj.backoff_AC1=0;
            obj.backoff_AC2=0;
            obj.backoff_AC3=0;
            %Define AIFS for each AC
            obj.AIFS_AC0=obj.AIFSN_AC0*obj.slotTime+obj.SIFS; % 0.149ms
            obj.AIFS_AC1=obj.AIFSN_AC1*obj.slotTime+obj.SIFS; % 0.110ms
            obj.AIFS_AC2=obj.AIFSN_AC2*obj.slotTime+obj.SIFS; % 0.071ms
            obj.AIFS_AC3=obj.AIFSN_AC3*obj.slotTime+obj.SIFS; % 0.058ms
            
            
            obj.intContention=0; %Internal Contention
                        
            %txNum records transmission time of one frame in each AC queue
            obj.txNum_AC0=0;
            obj.txNum_AC1=0;
            obj.txNum_AC2=0;
            obj.txNum_AC3=0;
            
            
            obj.RxDataSN=0;        
            
            obj.dataTxDelay=0.01;  % dataTxDelay= length(data)/bitrate                        
            obj.dataRxDelay=0.01;
            
            obj.ackTxRxDelay=975/10000000;
            obj.ackTimeout=2*obj.propTime/1000000+obj.SIFS+obj.ackTxRxDelay+obj.slotTime; 
            
            obj.waitForACK=zeros(10);
            obj.txType=0;
            
            obj.timestampBuffer=0;       
            obj.backoffPause=0;
            obj.payloadPosBuffer=zeros(1,2);
            
%           In DCF, EIFS = aSIFSTime + DIFS + ACKTxTime
%           In EDCA, EIFS - DIFS + AIFS[AC] = SIFS+ACKTxTime+AIFS[AC];
            obj.EIFS=obj.SIFS+ obj.ackTxRxDelay; % 97.5+ 32 + AIFS
            obj.rxCRCerr=0;
            
            obj.txPower=0;
            obj.srcAddress=0;
            obj.dstAddress=0;
            obj.RxACKSN=0;
            
            obj.txtEnable=1;
            obj.txtEnable=evalin('base','txtEnable');                       
            
            obj.V2Xmode='V2V';
            obj.V2Xmode = evalin('base', 'V2Xmode');
            
            obj.brakeMode='ConLaneChange';
            obj.brakeMode=evalin('base','brakeMode');            
        end
        
        %% matlab.sytem.mixin.Propagates
        function num=getNumInputsImpl(~)
            num=2;
        end
        
        function num=getNumOutputsImpl(~)
            num=2;
        end

        function [sz,dt,cp]=getDiscreteStateSpecificationImpl(~,~)
            sz=[1,1];
            dt='double';
            cp=false;
        end
        
        %% matlab.DiscreteEventSystem - setup storage 
        function entityTypes=getEntityTypesImpl(obj)
            entityTypes=[obj.entityType('payload','Payload')...
                         obj.entityType('frame','Frame')...
                         obj.entityType('waveform','Waveform')];
        end
        
        function [inputTypes,outputTypes]=getEntityPortsImpl(~)
            inputTypes={'payload','waveform'};
            outputTypes={'payload','waveform'};
        end
        
        function [storageSpec,I,O]=getEntityStorageImpl(obj)
            payloadStorage=obj.queueFIFO('payload',inf);    % 1-Payload buffer, input1 from upper layer.
            frameStorage=obj.queueFIFO('frame',inf);        % 2-frame buffer
            AC0=obj.queueFIFO('frame',inf);                 % 3-AC0
            AC1=obj.queueFIFO('frame',inf);                 % 4-AC1
            AC2=obj.queueFIFO('frame',inf);                 % 5-AC2
            AC3=obj.queueFIFO('frame',inf);                 % 6-AC3
            HCF=obj.queueFIFO('frame',inf);                 % 7-HCF
            Txwaveform=obj.queueFIFO('waveform',inf);       % 8-Txwaveform, Output 2 to wireless channel
            Rxwaveform=obj.queueFIFO('waveform',inf);       % 9-Rxwaveform, Input 2 from wireless channel
            TxFrame=obj.queueFIFO('payload',inf);           % 10- Output 1 to upper layer
            storageSpec=[payloadStorage,frameStorage,AC0,AC1,AC2,AC3,HCF,Txwaveform,Rxwaveform,TxFrame];            
            I=[1 9];
            O=[10 8];            
        end
                                    
       %% Self-defined methods
        % Listen - if channel is idle. 
        % Listen period -- AIFS
        % tag - AC0Listen <-> AC3Listen;
        % obj.hcfListen(entity,'AC0Listen',obj.AIFS_AC0);
        function events=hcfListen(obj,entity,tag)            
            coder.extrinsic('phy_ChannelSensing');
            coder.extrinsic('num2str');
            events=obj.initEventArray;
            hcfCS=0;
            hcfCS=phy_ChannelSensing(1,0,0); % Channel sensing
            tag=tag(tag~=0);
            if hcfCS==0  %Channel idle                
                switch tag
                    case 'AC0Listen'
                        
                        if obj.rxCRCerr==0 % Receive no Error packet, defer AIFS
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  frame' num2str(entity.data.SN) '(AC' num2str(entity.data.ACTag) ...
                                ')' ' sense idle channel, defer access AIFS_AC0 ' num2str(obj.AIFS_AC0*1000) 'ms']);%defer access to AIFS
                            end
                            events=obj.eventTimer('AC0AIFS',obj.AIFS_AC0);
                        elseif obj.rxCRCerr==1 % Receive Error packet, defer EIFS instead of AIFS
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  frame' num2str(entity.data.SN) '(AC' num2str(entity.data.ACTag) ...
                                ')' ' sense idle channel, defer access EIFS+AIFS_AC0 ' num2str((obj.EIFS+obj.AIFS_AC0)*1000) 'ms']);%defer access to AIFS                           
                            end
                            events=obj.eventTimer('AC0AIFS',obj.EIFS+obj.AIFS_AC0);
                        end
                        
                    case 'AC1Listen'                        
                        
                        if obj.rxCRCerr==0
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  frame' num2str(entity.data.SN) '(AC' num2str(entity.data.ACTag) ...
                                ')'  ' sense idle channel, defer access AIFS_AC1 ' num2str(obj.AIFS_AC1*1000) 'ms']);%defer access to AIFS
                            end
                            events=obj.eventTimer('AC1AIFS',obj.AIFS_AC1);
                        elseif obj.rxCRCerr==1
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  frame' num2str(entity.data.SN) '(AC' num2str(entity.data.ACTag) ...
                                ')'  ' sense idle channel, defer access EIFS+AIFS_AC1 ' num2str((obj.EIFS+obj.AIFS_AC1)*1000) 'ms']);%defer access to AIFS                            
                            end
                            events=obj.eventTimer('AC1AIFS',obj.EIFS+obj.AIFS_AC1);
                        end
                        
                    case 'AC2Listen'                                                
                        if obj.rxCRCerr==0
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  frame' num2str(entity.data.SN) '(AC' num2str(entity.data.ACTag) ...
                                ')'  ' sense idle channel, defer access AIFS_AC2 ' num2str(obj.AIFS_AC2*1000) 'ms']);%defer access to AIFS
                            end
                            events=obj.eventTimer('AC2AIFS',obj.AIFS_AC2);
                        elseif obj.rxCRCerr==1
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  frame' num2str(entity.data.SN) '(AC' num2str(entity.data.ACTag) ...
                                ')'  ' sense idle channel, defer access EIFS+AIFS_AC2 ' num2str((obj.EIFS+obj.AIFS_AC2)*1000) 'ms']);%defer access to AIFS
                            end
                            events=obj.eventTimer('AC2AIFS',obj.EIFS+obj.AIFS_AC2);
                        end
                        
                    case 'AC3Listen'                        
                        
                        if obj.rxCRCerr==0
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  frame' num2str(entity.data.SN) '(AC' num2str(entity.data.ACTag) ...
                                ')'  ' sense idle channel, defer access AIFS_AC3 ' num2str(obj.AIFS_AC3*1000) 'ms']);%defer access to AIFS
                            end
                            events=obj.eventTimer('AC3AIFS',obj.AIFS_AC3);
                        elseif obj.rxCRCerr==1
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  frame' num2str(entity.data.SN) '(AC' num2str(entity.data.ACTag) ...
                                ')'  ' sense idle channel, defer access obj.EIFS+AIFS_AC3 ' num2str((obj.EIFS+obj.AIFS_AC3)*1000) 'ms']);%defer access to AIFS                            
                            end
                            events=obj.eventTimer('AC3AIFS',obj.EIFS+obj.AIFS_AC3);
                        end
                        
                end                
            else
                if obj.txtEnable==1
                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  frame' num2str(entity.data.SN) '(AC' num2str(entity.data.ACTag) ...
                                ')'  ' sense busy channel, listen to another slottime ' num2str(obj.slotTime*1000) 'ms']);%defer access to AIFS
                end
                        events=obj.eventTimer(tag,obj.slotTime);% Listen                
            end  
        end
        


        % backoff;
        % Duty: 1. calculate contention window; 2. Set the AIFS timers to
        % call 'hcfBfCon' for AIFS by AIFS count down.
        function events=hcfBfStart(obj,entity,tag)                       
            coder.extrinsic('num2str');
            coder.extrinsic('randi');
%             rng(obj.txAddr);
%             
            tag=tag(tag~=0);
                    switch tag
                        case 'AC0backoff'                            
                            obj.backoff_AC0=randi([0 obj.CWmin_AC0]);
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  Frame ' num2str(entity.data.SN) ' (AC0) listen idle channel, backoff ' num2str(obj.backoff_AC0) ' timeslots;']);
                            end
                            if obj.backoff_AC0==0
                                if entity.data.Retry==0
                                    events=obj.intContentionCheck(entity);
                                else                      
                                    [~,events]=obj.extContentionCheck(entity);  
                                end 
                            else
                                if obj.txtEnable==1
                                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) '-------AC0 Backoff left:' num2str(obj.backoff_AC0) '----------']);                    
                                end
                                obj.backoff_AC0=obj.backoff_AC0-1;
                                events=obj.eventTimer(tag,obj.slotTime); 
                            end                                                                                    
                        case 'AC1backoff'
                            obj.backoff_AC1=randi([ 0 obj.CWmin_AC1]);
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  Frame ' num2str(entity.data.SN) '(AC1) listen idle channel,backoff ' num2str(obj.backoff_AC1) ' timeslots;']);
                            end
                            if obj.backoff_AC1==0
                                if entity.data.Retry==0
                                    events=obj.intContentionCheck(entity);
                                else                      
                                    [~,events]=obj.extContentionCheck(entity);  
                                end 
                            else
                                if obj.txtEnable==1
                                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) '-------AC1 Backoff left:' num2str(obj.backoff_AC1) '----------']);                    
                                end
                                obj.backoff_AC1=obj.backoff_AC1-1;
                                events=obj.eventTimer(tag,obj.slotTime); 
                            end
                            
                            
                        case 'AC2backoff'
                            
%                             
%                             temprandi  = randi([0 7]);
%                              disp(['randtemp= ' num2str(temprandi)]);
                            obj.backoff_AC2=randi([0 obj.CWmin_AC2]);
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  Frame ' num2str(entity.data.SN) '(AC2) listen idle channel,backoff ' num2str(obj.backoff_AC2) ' timeslots;']);
                            end
                            if obj.backoff_AC2==0
                                if entity.data.Retry==0
                                    events=obj.intContentionCheck(entity);
                                else                      
                                    [~,events]=obj.extContentionCheck(entity);  
                                end 
                            else
                                if obj.txtEnable==1
                                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) '-------AC2 Backoff left:' num2str(obj.backoff_AC2) '----------']);
                                end
                                obj.backoff_AC2=obj.backoff_AC2-1;
                                events=obj.eventTimer(tag,obj.slotTime); 
                            end
                            
                            
                        case 'AC3backoff'
                            obj.backoff_AC3=randi([0 obj.CWmin_AC3]);
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  Frame ' num2str(entity.data.SN) '(AC3) listen idle channel,backoff ' num2str(obj.backoff_AC3) ' timeslots;']);
                            end
                            if obj.backoff_AC3==0
                                if entity.data.Retry==0
                                    events=obj.intContentionCheck(entity);
                                else                      
                                    [~,events]=obj.extContentionCheck(entity);  
                                end 
                            else
                                if obj.txtEnable==1
                                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) '-------AC3 Backoff left:' num2str(obj.backoff_AC3) '----------']);                    
                                end
                                obj.backoff_AC3=obj.backoff_AC3-1;
                                events=obj.eventTimer(tag,obj.slotTime); 
                            end                                                        
                    end
                                   
        end
        
        % BackoffContinue called during backoff process AIFS by AIFS;
        % If backoff decrease to Zero, call internal Contention check;
        function events=hcfBfCont(obj,tag,entity)
            events=obj.initEventArray;
            tag=tag(tag~=0);
            switch tag
                case 'AC0backoff' 
                    if obj.backoff_AC0==0
                        if entity.data.Retry==0
                            events=obj.intContentionCheck(entity);
                        else                      
                            [~,events]=obj.extContentionCheck(entity);  
                        end 
                    else
                        obj.backoff_AC0=obj.backoff_AC0-1;
                        events=obj.eventTimer(tag,obj.slotTime);
                    end
                case 'AC1backoff'     
                    if obj.backoff_AC1==0
                        if entity.data.Retry==0
                            events=obj.intContentionCheck(entity);
                        else                      
                            [~,events]=obj.extContentionCheck(entity);  
                        end 
                    else
                        obj.backoff_AC1=obj.backoff_AC1-1;
                        events=obj.eventTimer(tag,obj.slotTime);
                    end
                case 'AC2backoff'   
                    if obj.backoff_AC2==0
                        if entity.data.Retry==0
                            events=obj.intContentionCheck(entity);
                        else                      
                            [~,events]=obj.extContentionCheck(entity);  
                        end 
                    else
                        obj.backoff_AC2=obj.backoff_AC2-1;
                        events=obj.eventTimer(tag,obj.slotTime);
                    end
                case 'AC3backoff'    
                    if obj.backoff_AC3==0
                        if entity.data.Retry==0
                            events=obj.intContentionCheck(entity);
                        else                      
                            [~,events]=obj.extContentionCheck(entity);  
                        end 
                    else
                        obj.backoff_AC3=obj.backoff_AC3-1;
                        events=obj.eventTimer(tag,obj.slotTime);
                    end
            end        
        end

        % Internal Contention Check
        % If internal contention exist, rebackoff
        % if no internal contention, forward 'Frame Entity' to 'HCF
        % Storage';
        function events=intContentionCheck(obj,entity)
            coder.extrinsic('num2str');
            if obj.intContention==0
%                 disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  Internal Contention Not Detected! Send to Tx Buffer......'])
                events=obj.eventForward('storage',7,0); %Forward to Tx buffer, storage 7 
                obj.intContention=1;
                switch entity.data.ACTag
                    case 0
                        obj.numFrame_AC0=obj.numFrame_AC0-1;
                    case 1
                        obj.numFrame_AC1=obj.numFrame_AC1-1;
                    case 2
                        obj.numFrame_AC2=obj.numFrame_AC2-1;
                    case 3
                        obj.numFrame_AC3=obj.numFrame_AC3-1;
                end                
            else
                if obj.txtEnable==1
                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':   Internal Contention Detected! Redo backoff .....@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.']);
                end
                events=obj.hcfReTx(entity);
            end
        end
        
        % External Check 
        % Task 1: Channel sensing, check if incoming transmission exist;
        % Task 2: Check is current node is transmitting;
        % Task 3: Buff the Sequence Number of packets awaiting sending.
        % Generate 'Waveform entity' in STORAGE 8; Create 'dataTx' timer
        % for simulating transmission delay.
        % If channel is busy or the current node is transmitting, redo backoff 
        function [entity,events]=extContentionCheck(obj,entity)
%             disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  retry times (extCon)' num2str(entity.data.Retry)]);                           
%             disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  External Contention NOT Detected! Send to Tx output......']);
%             disp(['dataTxDelay ' num2str(obj.dataTxDelay)]);                                    
                coder.extrinsic('num2str');
                coder.extrinsic('fcn_carGlobalDB');
                events=obj.initEventArray;
                
                obj.frameBodyBuffer=entity.data.Body;
                obj.TxACTag=entity.data.ACTag;
                obj.frameRetryBuffer=entity.data.Retry;
                
                if entity.data.Retry==0  % New frame                    
                   % Select receiver; 0 is broadcast; Then set to
                   % destination address: dstAddress
                                      
                    obj.dstAddress=entity.data.dstAddress;
                    
                    obj.frameSNBuffer=entity.data.SN;   
                    obj.timestampBuffer=entity.data.Timestamp;
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node'  num2str(obj.txAddr) ',  select destination: node ' num2str(obj.dstAddress)]); 
                    end
                    
                    
%                     if obj.infraAddress==0
                    if strcmp(obj.V2Xmode,'V2V')
                        entity.data.ToDS=0;
                        entity.data.FromDS=0;
                        entity.data.Address1=obj.dstAddress;
                        entity.data.Address2=obj.txAddr;
%                     elseif obj.infraAddress==88
                    elseif strcmp(obj.V2Xmode,'V2I')
                        entity.data.ToDS=1;
                        entity.data.FromDS=0;
                        entity.data.Address1=obj.infraAddress;
                        entity.data.Address2=obj.txAddr;
                        entity.data.Address3=obj.dstAddress;                        
                    else
                         if obj.txtEnable==1
                            disp('Error: wrong V2x mode selected.');
                         end
                     end

                    if obj.dstAddress~=0 && obj.dstAddress<1000000% Unicast              
                        % not support code generation
                        if ~ismember(obj.frameSNBuffer,obj.waitForACK)
                            pointer=length(obj.waitForACK(obj.waitForACK~=0))+1;
                            obj.waitForACK(pointer)=obj.frameSNBuffer;
%                             obj.waitForACK=[obj.waitForACK obj.frameSNBuffer];
                        end                            
                        switch entity.data.ACTag
                            case 0
                                events=obj.eventGenerate(8,'sendFrame_AC0',0,1);
                            case 1
                                events=obj.eventGenerate(8,'sendFrame_AC1',0,1);
                            case 2
                                events=obj.eventGenerate(8,'sendFrame_AC2',0,1);
                            case 3
                                events=obj.eventGenerate(8,'sendFrame_AC3',0,1);
                        end           
                        events=[events obj.eventTimer('dataTx',obj.dataTxDelay)];
                    else  % Broadcast 
                        switch entity.data.ACTag
                            case 0
                                events=obj.eventGenerate(8,'sendFrame_AC0',0,1);
                            case 1
                                events=obj.eventGenerate(8,'sendFrame_AC1',0,1);
                            case 2
                                events=obj.eventGenerate(8,'sendFrame_AC2',0,1);
                            case 3
                                events=obj.eventGenerate(8,'sendFrame_AC3',0,1);
                        end                    
                        events=[events obj.eventTimer('broadcast',obj.dataTxDelay)];
                    end     
                    
                    fcn_carGlobalDB('sent',entity.data.ACTag);
                    
                    
                else  % Retransmitted frame
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node'  num2str(obj.txAddr) ': This is a retransmitted frame']);
                    end
%                     disp(['(extCont-Retrans) entity.data.Address1 ' num2str(entity.data.Address1) 'entity.data.Address2 ' num2str(entity.data.Address2) 'entity.data.Address3 ' num2str(entity.data.Address3)]);
                    obj.frameSNBuffer=entity.data.SN;   
                    
                    if entity.data.ToDS==0 && entity.data.FromDS==0
                        obj.dstAddress=entity.data.Address1;                        
                    elseif entity.data.ToDS==1 && entity.data.FromDS==0
                        obj.dstAddress=entity.data.Address3;
                    else
                        if obj.txtEnable==1
                            disp('wrong ToDS/FromDS setting');
                        end
                    end                    
        
                      % not support code generation
                    if ~ismember(obj.frameSNBuffer,obj.waitForACK)
                        pointer=length(obj.waitForACK(obj.waitForACK~=0))+1;
                        obj.waitForACK(pointer)=obj.frameSNBuffer;
%                         obj.waitForACK=[obj.waitForACK obj.frameSNBuffer];
                    end                                        

                    switch entity.data.ACTag
                        case 0
                            events=obj.eventGenerate(8,'sendFrame_AC0',0,1);
                        case 1
                            events=obj.eventGenerate(8,'sendFrame_AC1',0,1);
                        case 2
                            events=obj.eventGenerate(8,'sendFrame_AC2',0,1);
                        case 3
                            events=obj.eventGenerate(8,'sendFrame_AC3',0,1);
                    end           
                    events=[events obj.eventTimer('dataTx',obj.dataTxDelay)];
                end
        end
        
        % Rebackoff happens when: 1. media is busy after last backoff (internal contention or external contention); 2. ACK not
        % received.
        % Duty: Double CWmin. Restart from 'Listen' stage.
        function events=hcfReBf(obj,entity)
            coder.extrinsic('num2str');
%             disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  retry times (hcfReBf)' num2str(entity.data.Retry)]);                
            events=obj.initEventArray;
            switch entity.data.ACTag
                case 0
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  rebackoff frame ' num2str(entity.data.SN)] );
                    end
                    if obj.CWmin_AC0*2<obj.CWmax_AC0
                        obj.CWmin_AC0=obj.CWmin_AC0*2;
                    else
                        obj.CWmin_AC0=obj.CWmax_AC0;
                    end
                    events=obj.hcfListen(entity, 'AC0Listen');
                case 1
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  rebackoff frame ' num2str(entity.data.SN)] );
                    end
                    if obj.CWmin_AC1*2<obj.CWmax_AC1
                        obj.CWmin_AC1=obj.CWmin_AC1*2;
                    else
                        obj.CWmin_AC1=obj.CWmax_AC1;
                    end
                    events=obj.hcfListen(entity, 'AC1Listen');
                case 2
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  rebackoff frame ' num2str(entity.data.SN)] );
                    end
                    if obj.CWmin_AC2*2<obj.CWmax_AC2
                        obj.CWmin_AC2=obj.CWmin_AC2*2;
                    else
                        obj.CWmin_AC2=obj.CWmax_AC2;
                    end
                    events=obj.hcfListen(entity, 'AC2Listen');
                case 3
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  rebackoff frame ' num2str(entity.data.SN)] );
                    end
                    if obj.CWmin_AC3*2<obj.CWmax_AC3
                        obj.CWmin_AC3=obj.CWmin_AC3*2;
                    else
                        obj.CWmin_AC3=obj.CWmax_AC3;
                    end
                    events=obj.hcfListen(entity, 'AC3Listen');
            end
            
        end
        
        % ReTransmission happens when ACK is timeout or corrupted.
        % obj.txNum record the number of transmission;
        % Check if retransmission times reach Retry_MAX: Yes - drop, send
        % next if there is any;  No - rebackoff, retransmit;
        function events=hcfReTx(obj,entity)
            coder.extrinsic('num2str');
            events=obj.initEventArray;
            switch entity.data.ACTag
                case 0
                    if obj.txNum_AC0==obj.Retry_MAX      %Retrans time more than 3, drop
                        obj.txNum_AC0=0;                    % Reset transmision times
                        obj.CWmin_AC0=obj.aCWmin;           % Reset CWmin
                        if obj.txtEnable==1
                            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  retransmit 3 times, dropped, send next.']);                            
                        end                                                                       
                        
                         if ismember(entity.data.SN,obj.waitForACK) % Make sure the ACK is to the right data                                                                                               
                            for i=1:length(obj.waitForACK)                                           
                                if obj.waitForACK(i)==entity.data.SN                                
                                    obj.waitForACK(i)=0;                                    
                                    tempArray=obj.waitForACK(obj.waitForACK~=0);                                    
                                    tempIndex=length(tempArray);                                    
                                    obj.waitForACK(1:tempIndex)=tempArray;                                    
                                end                                
                            end
                         end
                        
                        if obj.numFrame_AC0>1               % If more packets are waiting, prepare to send next;
                            events=obj.eventIterate(3,'nextAC0',1);
                        else                                % If no packets in the AC queue, stay sleep;
%                             events=obj.hcfSleep();
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  has no more frames in AC' num2str(entity.data.ACTag) ' stored']);
                            end
                        end
                        events=[events obj.eventDestroy()];
                    else 
                        obj.txNum_AC0=obj.txNum_AC0+1;      % Transmission times increases by 1
%                         entity.data.Retry=1;
                        events=obj.hcfReBf(entity);         % Redo backoff 
                    end
                case 1
                    if obj.txNum_AC1==obj.Retry_MAX      %Retrans time more than 3, drop
                        obj.txNum_AC1=0;
                        obj.CWmin_AC1=obj.aCWmin;                        
                        if obj.txtEnable==1
                            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': retransmit 3 times, dropped, send next.']);
                        end
                        
                        if obj.txtEnable==1
                            %%disp(['^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^SN ' num2str(entity.data.SN) ' waitforACK: ' num2str(obj.waitForACK) '^^^^^^^^^^^^^^^^^^^^^^']);
                        end
                        if ismember(entity.data.SN,obj.waitForACK) % Make sure the ACK is to the right data                                                                                               
%                             obj.waitForACK=obj.waitForACK(obj.waitForACK~=entity.data.SN);
                            for i=1:length(obj.waitForACK)                                           
                                if obj.waitForACK(i)==entity.data.SN                                
                                    obj.waitForACK(i)=0;                                    
                                    tempArray=obj.waitForACK(obj.waitForACK~=0);                                    
                                    tempIndex=length(tempArray);                                    
                                    obj.waitForACK(1:tempIndex)=tempArray;                                    
                                end                                
                            end
                         end
                        if obj.numFrame_AC1>1
                            events=obj.eventIterate(4,'nextAC1',1);
                        else
%                             events=obj.hcfSleep();
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': has no more frames in AC' num2str(entity.data.ACTag) ' stored']);
                            end
                        end
                        events=[events obj.eventDestroy()];
                    else 
                        obj.txNum_AC1=obj.txNum_AC1+1;
%                         entity.data.Retry=1;
                        events=obj.hcfReBf(entity);
                    end
                case 2
                    if obj.txNum_AC2==obj.Retry_MAX      %Retrans time more than 3, drop
                        obj.txNum_AC2=0;
                        obj.CWmin_AC2=obj.aCWmin;                        
                        if obj.txtEnable==1
                            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': retransmit 3 times, dropped, send next.']);
                            %%disp(['^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^SN ' num2str(entity.data.SN) ' waitforACK: ' num2str(obj.waitForACK) '^^^^^^^^^^^^^^^^^^^^^^']);
                        end
                        
                        if ismember(entity.data.SN,obj.waitForACK) % Make sure the ACK is to the right data                                                                                               
%                             obj.waitForACK=obj.waitForACK(obj.waitForACK~=entity.data.SN);
                            for i=1:length(obj.waitForACK)
                                if obj.waitForACK(i)==entity.data.SN    
                                    obj.waitForACK(i)=0;        
                                    tempArray=obj.waitForACK(obj.waitForACK~=0);        
                                    tempIndex=length(tempArray);        
                                    obj.waitForACK(1:tempIndex)=tempArray;        
                                end    
                            end
                        end
                        if obj.numFrame_AC2>1
                            events=obj.eventIterate(5,'nextAC2',1);
                        else
%                             events=obj.hcfSleep();                            
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ': node' num2str(obj.txAddr) ' has no more frames in AC' num2str(entity.data.ACTag) ' stored']);
                            end
                        end
                        events=[events obj.eventDestroy()];
                    else 
                        obj.txNum_AC2=obj.txNum_AC2+1;
%                         entity.data.Retry=1;
                        events=obj.hcfReBf(entity);
                    end
                case 3

                    if obj.txNum_AC3==obj.Retry_MAX     %Retrans time more than 3, drop
                        obj.txNum_AC3=0;
                        obj.CWmin_AC3=obj.aCWmin;                        
                        if obj.txtEnable==1
                            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': retransmit 3 times, dropped, send next.']);
%                             %%disp(['^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^SN ' num2str(entity.data.SN) ' waitforACK: ' num2str(obj.waitForACK) '^^^^^^^^^^^^^^^^^^^^^^']);
                        end
                        
                        
                        if ismember(entity.data.SN,obj.waitForACK) % Make sure the ACK is to the right data                                                                                               
%                             obj.waitForACK=obj.waitForACK(obj.waitForACK~=entity.data.SN);
                            for i=1:length(obj.waitForACK)
                                if obj.waitForACK(i)==entity.data.SN    
                                    obj.waitForACK(i)=0;        
                                    tempArray=obj.waitForACK(obj.waitForACK~=0);        
                                    tempIndex=length(tempArray);        
                                    obj.waitForACK(1:tempIndex)=tempArray;        
                                end    
                            end
                        end
%                         disp(['Updated WaitforACK ' num2str(obj.waitForACK)]); 
                        if obj.numFrame_AC3>1
                            events=obj.eventIterate(6,'nextAC3',1);
                        else
%                             events=obj.hcfSleep();
                            if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  has no more frames in AC' num2str(entity.data.ACTag) ' stored']);
                            end
                        end
                        
                        % -----------Performance lane changing special                                       
                        if strcmp(obj.brakeMode,'PerLaneChange') && entity.data.Address2==obj.PLCA                                                
                            events=[events obj.eventGenerate(10,'mgmGenUnACKed',0,10)];
                        end
                        %-----------------------------------------------------------------
                        
                        events=[events obj.eventDestroy()];
                    else                          
                        obj.txNum_AC3=obj.txNum_AC3+1;
%                         entity.data.Retry=1;
                        events=obj.hcfReBf(entity);
                    end
            end
                
        end        
        
    end
    
    methods
        function events=setupEvents(obj)            
            coder.extrinsic('phy_ChannelSensing');
            coder.extrinsic('evalin');
            coder.extrinsic('num2str');
            
            events=obj.initEventArray;
            phy_ChannelSensing(0,0,0);
            phy_ChannelSensing(2,0,0);
            
            if strcmp(obj.V2Xmode,'V2V')
                disp(['Node ' num2str(obj.txAddr) ' V2V mode selected!']);       
            elseif strcmp(obj.V2Xmode,'V2I')
                disp(['Node ' num2str(obj.txAddr) ' V2I mode selected! RSU address is ' num2str(obj.infraAddress)]);       
            else
                disp('Warning: V2x mode error! (0 or 1)')
            end       
                                           
        end
        
       %% matlab.DiscreteEventSystem - action methods
         
        % Action when 'Payload entity' enters STORAGE 1 of MAC layer;
        % Gather all info preparing for generating 'Frame entity';
        % 1. payloadCounter --> Frame Sequence Number (entity.data.SN);
        % 2. payload buffer --> Frame body (entity.data.Body);
        % 3. priority buffer--> Frame priority       
        function [entity,events] = payloadEntry(obj,~,entity,~)
            coder.extrinsic('num2str');
%             coder.extrinsic('str2num');
            coder.extrinsic('str2double');
            coder.extrinsic('evalin');
            coder.extrinsic('phy_psdu2waveform_data_mex');
            
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('mac');
            
            obj.payloadCounter=obj.payloadCounter+1; % In frameGenerateImpl(), entity.data.SN=obj.payloadCounter;            
            obj.txPayloadBuffer=entity.data.wsmp;
            obj.txPayloadPriority=entity.data.priority;                                           
            obj.payloadPosBuffer=entity.data.pos;
            obj.dstAddress=entity.data.dstAddress; 
                                  
            if strcmp(obj.brakeMode,'PerLaneChange')
                if entity.data.dstAddress>1000000
                    tempAdd='1000000';
                    tempAdd=num2str(entity.data.dstAddress);  
                    
                    frontAddress=0;
                    backAddress=0;                    
%                     frontAddress=str2num(tempAdd(2:4));
%                     backAddress=str2num(tempAdd(5:7));
                    
                    frontAddress=str2double(tempAdd(2:4));
                    backAddress=str2double(tempAdd(5:7));
                    
                    if frontAddress~=0
                        obj.dstAddress=frontAddress;
                    else
                        obj.dstAddress=backAddress;                     
                    end
                    
                end
                obj.PLCA=obj.dstAddress; % Performance Lane Changing Address (PLCA) unique;
            end
            
                        
%             [waveform,~]=phy_psdu2waveform(0,0,0,obj.txPayloadBuffer);  
            [waveform,~]=phy_psdu2waveform_data_mex(0,0,obj.txPayloadBuffer);  
            obj.dataTxDelay=length(waveform)/10000000;
            
            events=[obj.eventGenerate(2,'frame',0,1) obj.eventDestroy()];     %Switch from payload type to frame type              
            if obj.txtEnable==1
                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': frame' num2str(obj.payloadCounter) ' generated.']);
            end
        end
        
        % Generate 'Frame entity' in STORAGE 2.
        % Frame entity.data contains: 1. Payload 2.SN 3. ACTag.
        % Frame eneitty.sys contains: entity priority.
        % FORWARD each Frame entity to each AC queues.
        function [entity,events]=frameGenerate(obj,~,entity,~)    
            coder.extrinsic('num2str');    
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('mac');
            
            entity.data.Body=obj.txPayloadBuffer;            
            entity.data.SN=obj.payloadCounter;            
            entity.data.Retry=0;                                
            entity.data.Timestamp=obj.getCurrentTime();
            entity.data.dstAddress=obj.dstAddress;
                    
            switch obj.txPayloadPriority            
                case {1,2}  %AC0%                                 
                    entity.data.ACTag=0;                                              
                    entity.sys.priority=40;                    
                    events=obj.eventForward('storage',3,0);                    
                    if obj.txtEnable==1                    
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': frame' num2str(entity.data.SN) ' forwarded to AC0']);                        
                    end
                    
                case {0,3}  %AC1                
                    entity.data.ACTag=1;                    
                    entity.sys.priority=30;                    
                    events=obj.eventForward('storage',4,0);                    
                    if obj.txtEnable==1                                                   
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': frame' num2str(entity.data.SN) ' forwarded to AC1']);                        
                    end
                    
                case {4,5}  %AC2                
                    entity.data.ACTag=2;
                    entity.sys.priority=20;
                    events=obj.eventForward('storage',5,0);                    
                    if obj.txtEnable==1                    
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': frame' num2str(entity.data.SN) ' forwarded AC2']);                        
                    end
                    
                case {6,7}  %AC3               
                    entity.data.ACTag=3;                    
                    entity.sys.priority=10;                    
                    events=obj.eventForward('storage',6,0);                    
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': frame' num2str(entity.data.SN) ' forwarded to AC3']);
                    end
                    
                otherwise                    
                    events=obj.initEventArray;
                    
            end            
        end
        
        
        
        % Triger Conditions: 1. Frame entity generated in STORAGE 2, and
        % then forwarded to STORAGE 3(AC0),4(AC1),5(AC2),6(AC3) based on
        % Priority. When entered, set the numFrame_ACx counter; The 1st
        % frame in the AC queue starts 'Listen process' immediately.
        
        % 2. Frame to be transmitted will be 'FORWARD' to STORAGE 7 (HCF
        % storage); When entered, set internal contention to busy status
        % (intContention=1); Start to do external contention check
        % (extContentionCheck);
        function [entity,events]=frameEntry(obj,storage,entity,~)
            coder.extrinsic('num2str');    
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('mac');
            events=obj.initEventArray;                
                switch storage
                    case 3          %AC0                               
                        obj.numFrame_AC0=obj.numFrame_AC0+1;                        
                        disp(['numFrame_AC0 ' num2str(obj.numFrame_AC0)]);
                        if obj.numFrame_AC0==1                             
                            events=obj.hcfListen(entity,'AC0Listen');
%                             obj.isFirstAC0=0;
                        end
                    case 4          %AC1  
%                         disp(['numFrame_AC1' num2str(obj.numFrame_AC1)]);
                        obj.numFrame_AC1=obj.numFrame_AC1+1;
                        if obj.numFrame_AC1==1
                            events=obj.hcfListen(entity, 'AC1Listen');
%                             obj.isFirstAC1=0;
                        end
                    case 5          %AC2                        
                        obj.numFrame_AC2=obj.numFrame_AC2+1;                        
                        if obj.numFrame_AC2==1
                            events=obj.hcfListen(entity,'AC2Listen');
%                             obj.isFirstAC2=obj.isFirstAC2-1;
                        else
                            events=obj.eventIterate(5,'clearOldFramesforNewBSMs',1);
                        end
                    case 6          %AC3
%                         disp(['numFrame_AC3' num2str(obj.numFrame_AC3)]);
                        obj.numFrame_AC3=obj.numFrame_AC3+1;
                        if obj.numFrame_AC3==1
                            events=obj.hcfListen(entity,'AC3Listen');
%                             obj.isFirstAC3=0;
                        end   
                    case 7           %HCF Tx buffer
%                         disp('frame enters storage 7,start extCon check');                        
                        [entity,events]=obj.extContentionCheck(entity);   
                end          
        end
        
        
        function [entity,events]=payloadGenerate(obj,storage,entity,tag)
            coder.extrinsic('evalin');
            coder.extrinsic('app_msg2wsmp');
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('mac');
            assert(storage==10);
            events=obj.initEventArray;
            tag=tag(tag~=0);
            switch tag               
                case 'RxPayload'
                    entity.data.wsmp=obj.rxPayloadBuffer;                    
                    events=obj.eventForward('output',1,0);
                case 'mgmGenACKed'                    
                    disp('Generate management frames for ACK.');
                    msgType=111;
                    entity.data.wsmp=app_msg2wsmp(msgType,entity.data.wsmp,1); 
                    entity.data.wsmp=app_msg2wsmp(abs('A'),entity.data.wsmp,2);
                    events=obj.eventForward('output',1,0);
                case 'mgmGenUnACKed'                    
                    disp('Generate management frames for UnACK.');
                    msgType=111;
                    entity.data.wsmp=app_msg2wsmp(msgType,entity.data.wsmp,1); 
                    entity.data.wsmp=app_msg2wsmp(abs('U'),entity.data.wsmp,2);
                    events=obj.eventForward('output',1,0);
            end
            
        end                
            
        function [entity,events]=waveformEntry(obj,~,entity,~)    
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('phy');
            coder.extrinsic('num2str');
            events=obj.initEventArray;
            distance=sqrt((entity.data.pos(1)-obj.payloadPosBuffer(1))^2+(entity.data.pos(2)-obj.payloadPosBuffer(2))^2);
            airPropDelay=distance/(3*10^8);
                                                                
            if airPropDelay~=0
                events=obj.eventTimer('rcvWaveform',airPropDelay);                                                
%                 disp([num2str(obj.getCurrentTime()*1000000) '--waveformEntry--' num2str(airPropDelay*1000000)]);
            end
        end        
        
        function [entity,events]=waveformTimer(obj,storage,entity,tag)
            coder.extrinsic('num2str');                
            coder.extrinsic('str2double');            
%             coder.extrinsic('phy_waveform2psdu_ACK');            
            coder.extrinsic('phy_waveform2psdu_data');
            coder.extrinsic('phy_waveform2psdu_ack');
            coder.extrinsic('fcn_carGlobalDB');
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('phy');
            events=obj.initEventArray();
            
            tag=tag(tag~=0);
            
            if strcmp(tag,'rcvWaveform')                
%                 disp([num2str(obj.getCurrentTime()*1000000) 'waveformTimer']);
                obj.numRx=obj.numRx+1;        

                status=1;
                outframe=zeros(1,800);
                outmsg='1234567';
                typeField=1;
                subtype=1;


                if entity.data.Address2~=obj.txAddr
                    distance=sqrt((entity.data.pos(1)-obj.payloadPosBuffer(1))^2+(entity.data.pos(2)-obj.payloadPosBuffer(2))^2);
                    SNR =phy_pathlost(distance);            
                else
                    SNR=40;
                end



                if sum(entity.data.ACKBody)==0  % Receive Data  
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  receives ' num2str(obj.numRx) ' data.']);                      
                    end
                    [ status, outframe, outmsg, typeField, subtype ] = phy_waveform2psdu_data(entity.data.Body,SNR,entity.data.Length );       
                else
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  receives ' num2str(obj.numRx) ' ACK.']);  
                    end
                    [ status, ~, outmsg, typeField, subtype ] = phy_waveform2psdu_ack(entity.data.ACKBody,SNR,entity.data.Length );
                end            

                if status==1 %Received correctly  
                    rcvAddress=zeros(1,2);
                    if entity.data.Address1>1000000
                        tempAdd='1000000';
                        tempAdd=num2str(entity.data.Address1);                                        
                        rcvAddress(1)=str2double(tempAdd(2:4));
                        rcvAddress(2)=str2double(tempAdd(5:7));                     
                    elseif entity.data.Address1>0                    
                        rcvAddress(1)=entity.data.Address1;
                    end


                    obj.rxCRCerr=0;
    %                 if (entity.data.ToDS==0 && entity.data.FromDS==0 && entity.data.Address1==obj.txAddr)... % V2V unicast packet
                    if (entity.data.ToDS==0 && entity.data.FromDS==0 && ismember(obj.txAddr,rcvAddress))... % V2V unicast packet
                    || (entity.data.ToDS==0 && entity.data.FromDS==0 && entity.data.Address1==0 && entity.data.Address2~=obj.txAddr)...          % V2V broadcast packet
                    || (entity.data.ToDS==0 && entity.data.FromDS==1 && entity.data.Address1==0 && entity.data.Address2==obj.infraAddress && entity.data.Address3~=obj.txAddr)... %V2I broadcast packet
                    || (entity.data.ToDS==0 && entity.data.FromDS==1 && entity.data.Address1==obj.txAddr && entity.data.Address2==obj.infraAddress && entity.data.Address3~=obj.txAddr)    %V2I unicast packet
    %                     switch outframe.typeField                           
                       switch typeField
                            case 1              % Rcv ACK: type -> 1 subtype -> 13
                                if subtype==13    %receive ACK
                                    if entity.data.Address1==obj.txAddr
    %                                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node'  num2str(obj.txAddr) ' ACK SN: ' num2str(entity.data.SN) ' Unacked Packet SN: ' num2str(obj.waitForACK)]);                                                                                                                
                                        if ismember(entity.data.SN,obj.waitForACK)  % Make sure the ACK is to the right data%   
                                            if obj.txtEnable==1                                                
                                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  frame ' num2str(entity.data.SN) ' is acked successfully!']);                            %                                           
                                            end
                                            
                                            obj.RxACKSN=entity.data.SN;   

                                            events=[obj.eventIterate(7,'ackOK',1)...                                                          
                                            obj.eventDestroy()];

                                            % -----------Performance lane changing special                                       
                                            if strcmp(obj.brakeMode,'PerLaneChange') && entity.data.Address2==obj.PLCA                                                
                                                events=[events obj.eventGenerate(10,'mgmGenACKed',0,10)];
                                            end
                                            %-----------------------------------------------------------------

                                            for i=1:length(obj.waitForACK)
                                                if obj.waitForACK(i)==entity.data.SN    
                                                    obj.waitForACK(i)=0;        
                                                    tempArray=obj.waitForACK(obj.waitForACK~=0);        
                                                    tempIndex=length(tempArray);        
                                                    obj.waitForACK(1:tempIndex)=tempArray;        
                                                end 
                                            end
                                        else  % ACK is not to the right data
                                            if obj.txtEnable==1    
                                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node'  num2str(obj.txAddr) 'This ACK is invalid,i.e., sequence number does not match, discard!']); %        
                                            end    
                                            events=obj.eventDestroy();    
                                        end                                                                                                                                                                            
                                    else
                                        if obj.txtEnable==1
                                            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node'  num2str(obj.txAddr) 'This ACK is not for me, discard!']);
                                        end
                                        events=obj.eventDestroy();
                                    end        
                                else
                                    if obj.txtEnable==1
                                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node'  num2str(obj.txAddr) 'This is not an ACK frame']);
                                    end
                                    events=obj.eventDestroy();
                                end

                            case 2              % Rcv data: type -> 2   

                                if entity.data.Address1==0 || (entity.data.Address1>=1000000&&ismember(obj.txAddr,rcvAddress)) % Broadcast or multicast  packet, do not send ACK back
                                    fcn_carGlobalDB('latency',entity.data.ACTag,obj.getCurrentTime()-entity.data.Timestamp);

                                    if obj.txtEnable==1
                                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': frame ' num2str(entity.data.SN) ' received from broadcast correctly!  No ACK needed.']);
                                    end
                                    obj.RxDataSN=entity.data.SN;

                                    obj.rxPayloadBuffer=outframe;
                                    events=[obj.eventGenerate(10,'RxPayload',0,20)...   % send payload to upper layer
                                            obj.eventDestroy()];                            
                                elseif obj.txAddr == entity.data.Address1 % This is a unicast packet, need to send ACK back                                                            
                                    fcn_carGlobalDB('latency',entity.data.ACTag,obj.getCurrentTime()-entity.data.Timestamp);
                                    if entity.data.FromDS==1
                                        if obj.txtEnable==1
                                            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': data ' num2str(entity.data.SN) ' received from node' num2str(entity.data.Address3) 'via AP ' num2str(entity.data.Address2)  ' correctly!  Prepare for ACK......']);
                                        end
                                    elseif entity.data.FromDS==0
                                        if obj.txtEnable==1
                                            disp(['TTTTTTTTTT= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': data ' num2str(entity.data.SN) ' received from node' num2str(entity.data.Address2) ' correctly!  Prepare for ACK......']);
                                        end
                                    end
                                    obj.RxDataSN=entity.data.SN;                                
                                    if entity.data.ToDS==0 && entity.data.FromDS==0
                                        obj.srcAddress=entity.data.Address2;
                                    elseif entity.data.ToDS==0 && entity.data.FromDS==1
                                        obj.srcAddress=entity.data.Address3;
                                    end                                                                
                                    obj.rxPayloadBuffer=outframe;
                                    events=[obj.eventGenerate(8,'sendACK',obj.SIFS,100)...     % generate ACK
                                            obj.eventGenerate(10,'RxPayload',0,20)...   % send payload to upper layer
                                            obj.eventDestroy()];

                                else
                                    if obj.txtEnable==1
                                        disp('This msg is not for me, discard!');
                                    end
                                    events=obj.eventDestroy();
                                end                        
                        end     
                    else % Invalid ToDS/FromDS/Address
    %                     disp(['entity.data.ToDS ' num2str(entity.data.ToDS) ' entity.data.FromDS ' num2str(entity.data.FromDS) ' entity.data.Address1 ' num2str(entity.data.Address1)]);
                        if obj.txtEnable==1
                            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': receive correct packets but not for me.' ]);
                        end
                        events=obj.eventDestroy();
                    end
                elseif status==0 %Corrupted
                    obj.rxCRCerr=1;
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': ' outmsg '--> destroyed!']);
                    end
                    if (entity.data.ToDS==0 && entity.data.FromDS==0 && entity.data.Address1==obj.txAddr) || (entity.data.ToDS==0 && entity.data.FromDS==1 && entity.data.Address2==obj.infraAddress) || (entity.data.ToDS==0 && entity.data.FromDS==0 && entity.data.Address1==0)
                        if sum(entity.data.ACKBody)==0  % Receive Data  

                            fcn_carGlobalDB('CRCerror',entity.data.ACTag);
                        end
                    end
                    events=obj.eventDestroy();                
                end   
            end
        end
        
        function [entity,events,next]=frameIterate(obj,~,entity,tag,cur)
            coder.extrinsic('num2str');
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('mac');
            next=false;
            events=obj.initEventArray;
            tag=tag(tag~=0);
            switch tag
                case 'ackOK'
                    if entity.data.SN==obj.RxACKSN
                        switch entity.data.ACTag
                            case 0
%                                 disp('Frame from AC0 is destroyed');
                                if obj.numFrame_AC0>=1
                                    events=obj.eventIterate(3,'nextAC0',10);
                                else
%                                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': no more frames in AC0...']);
%                                     obj.isFirstAC0=1;
                                end
                            case 1
%                                 disp('Frame from AC1 is destroyed')
                                if obj.numFrame_AC1>=1
                                    events=obj.eventIterate(4,'nextAC1',10);
                                else
%                                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': no more frames in AC1...']);
%                                     obj.isFirstAC1=1;
                                end
                            case 2
%                                 disp('frame from AC2 is destroyed');
                                if obj.numFrame_AC2>=1
                                    events=obj.eventIterate(5,'nextAC2',10);
                                else
%                                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': no more frames in AC2...']);
%                                     obj.isFirstAC2=1;
                                end
                                
                            case 3
%                                 disp(['frame from AC3 is destroyed' num2str(obj.numFrame_AC3)]);
                                if obj.numFrame_AC3>=1
                                    events=obj.eventIterate(6,'nextAC3',10);
                                else
%                                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': no more frames in AC3...']);
%                                     obj.isFirstAC3=1;
                                end
                        end
                        events=[events obj.eventDestroy()];
                        next=false;
                    else
%                         events=obj.initEventArray;
                        next=true;
                    end
                case 'nextAC0'
                    if obj.txtEnable==1
                        disp('Iterate AC0');   
                    end
                    if cur.position==1
                        events=obj.hcfListen(entity,'AC0Listen');
                        next=false;
                    end
                case 'nextAC1'
                    if obj.txtEnable==1
                        disp('Iterate AC1');
                    end
                    if cur.position==1
                        events=obj.hcfListen(entity, 'AC1Listen');
                        next=false;
                    end
                case 'nextAC2'
                    if obj.txtEnable==1
                        disp('Iterate AC2');
                    end
                    if cur.position==1
                        events=obj.hcfListen(entity, 'AC2Listen');
                        next=false;
                    end
                case 'nextAC3'
                    if obj.txtEnable==1
                        disp('Iterate AC3');
                    end
                    if cur.position==1
                        events=obj.hcfListen(entity, 'AC3Listen');
                        next=false;
                    end
                case 'clearOldFramesforNewBSMs'
                    if cur.position<cur.size
                        events=obj.eventDestroy();
                        obj.numFrame_AC2=obj.numFrame_AC2-1;
                        next=true;
                    else
                        disp('old frames in AC2 are cleared');
                        events=obj.hcfListen(entity,'AC2Listen');
                    end
            end
        end
        

        function events=waveformDestroy(obj,storage,~)
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('phy');
            assert(storage==9);            
            obj.numRx=obj.numRx-1;
            events=obj.initEventArray;        
        end
        
        % waveform generated in Storage 8, ready to send.
        function [entity,events]=waveformGenerate(obj,~,entity,tag) 
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('phy');
            coder.extrinsic('phy_psdu2waveform_ack_mex');
            coder.extrinsic('phy_psdu2waveform_data_mex');
            tag=tag(tag~=0);
            entity.data.pos=obj.payloadPosBuffer;
            switch tag                                    
                case 'sendACK'  % Send ACK
                    entity.sys.priority=1;
                    entity.data.Control=13;
                    entity.data.SN=obj.RxDataSN;
%                     [entity.data.ACKBody,entity.data.Length]=phy_psdu2waveform(1,obj.srcAddress);                                                           
                    [entity.data.ACKBody,entity.data.Length]=phy_psdu2waveform_ack_mex(obj.srcAddress);
                    if strcmp(obj.V2Xmode,'V2V')
                        entity.data.ToDS=0;
                        entity.data.FromDS=0;
                        entity.data.Address1=obj.srcAddress;
                        entity.data.Address2=obj.txAddr;
                    elseif strcmp(obj.V2Xmode,'V2I')
                        entity.data.ToDS=1;
                        entity.data.FromDS=0;
                        entity.data.Address1=obj.infraAddress;
                        entity.data.Address2=obj.txAddr;
                        entity.data.Address3=obj.srcAddress;                        
                    else
                        if obj.txtEnable==1
                            disp('Error: wrong V2x mode selected.');
                        end
                        
                    end
                    % turn off ack sending temporarily
                    events=obj.eventForward('output',2,0);   
%                     events=obj.initEventArray;
                    
                otherwise %Send data waveform
                    entity.data.Control=8;
                    entity.data.SN=obj.frameSNBuffer;       
                    entity.data.Timestamp=obj.timestampBuffer;
                    %Convert psdu to waveform
%                     [waveform,entity.data.Length]=phy_psdu2waveform(0,obj.txAddr,obj.dstAddress,obj.frameBodyBuffer);          
                    [waveform,entity.data.Length]=phy_psdu2waveform_data_mex(obj.txAddr,obj.dstAddress,obj.frameBodyBuffer); 
                    entity.data.Body=waveform;                        
                    switch tag
                        case 'sendFrame_AC0'
                            entity.data.ACTag=0;
                            entity.sys.priority=40;
                        case 'sendFrame_AC1'
                            entity.data.ACTag=1;
                            entity.sys.priority=30;
                        case 'sendFrame_AC2'
                            entity.data.ACTag=2;
                            entity.sys.priority=20;
                        case 'sendFrame_AC3'
                            entity.data.ACTag=3;
                            entity.sys.priority=10;
                    end    

                    if strcmp(obj.V2Xmode,'V2V')
                        entity.data.Address1=obj.dstAddress; % Destination address
                        entity.data.Address2=obj.txAddr;     % Sender address                                   
                        entity.data.ToDS=0;
                        entity.data.FromDS=0;
                    elseif strcmp(obj.V2Xmode,'V2I')
                        entity.data.ToDS=1;
                        entity.data.FromDS=0;
                        entity.data.Address1=obj.infraAddress; % AP address
                        entity.data.Address2=obj.txAddr;       % Sender address
                        entity.data.Address3=obj.dstAddress;   % Destination address
                    else
                        if obj.txtEnable==1
                            disp('Warning: V2x mode error! (0 or 1)')
                        end
                        
                    end
                    
                    events=obj.eventForward('output',2,0);
                    
            end
        end                                    
       
        function events=waveformExit(obj,storage,entity,~)
            coder.extrinsic('num2str');
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('phy');
            events=obj.initEventArray;
            if storage ==8
                if entity.data.Control==8
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  waveform' num2str(entity.data.SN) ' sent.'])
                    end
                elseif entity.data.Control==13
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  ACK' num2str(entity.data.SN) ' is sending...'])
                    end
                end                
            end
        end
        
        function [entity,events]=frameTimer(obj,storage,entity,tag)   
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('mac');
            events=obj.initEventArray;
            coder.extrinsic('phy_ChannelSensing');
            coder.extrinsic('num2str');
            hcfCS=1;
            hcfCS=phy_ChannelSensing(1,0,0); % Channel sensing
            tag=tag(tag~=0);
            switch tag                
                case {'AC0Listen','AC1Listen','AC2Listen','AC3Listen'}                       
                    events=obj.hcfListen(entity,tag);               
                case 'AC0AIFS'                    
                    if hcfCS==0  %Channel free
                        
                        if obj.backoffPause==0   % new backoff 
    %                       disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': frame ' num2str(entity.data.SN) ' starts backoff!']);
                            events=obj.hcfBfStart(entity,'AC0backoff');% backoff
                        else % resume backoff 
                           if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': frame ' num2str(entity.data.SN) ' resumes backoff!']);
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) '-------AC0 Backoff left:' num2str(obj.backoff_AC0) '----------']);                    
                           end
                           events=obj.hcfBfCont('AC0backoff',entity);
%                             events=obj.eventTimer('AC0backoff',0);
                           obj.backoffPause=0;
                        end    
                        
                    else
                        events=obj.hcfListen(entity,'AC0Listen');
                    end
                case 'AC1AIFS'
                    if hcfCS==0   %Channel free
                         if obj.backoffPause==0                              
                            %backoff start
    %                       disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': frame ' num2str(entity.data.SN) ' starts backoff!']);
                            events=obj.hcfBfStart(entity,'AC1backoff');% backoff
                         else
                           %backoff resume
                           if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': frame ' num2str(entity.data.SN) ' resumes backoff!']);
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) '-------AC1 Backoff left:' num2str(obj.backoff_AC1) '----------']);                    
                           end
                           events=obj.hcfBfCont('AC1backoff',entity);      
%                             events=obj.eventTimer('AC0backoff',0);
                           obj.backoffPause=0;
                         end                    
                    else
                        events=obj.hcfListen(entity,'AC1Listen');
                    end
                case 'AC2AIFS'
                    if hcfCS==0   %Channel free
                         if obj.backoffPause==0              %backoff start
    %                       disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': frame ' num2str(entity.data.SN) ' starts backoff!']);
                            events=obj.hcfBfStart(entity,'AC2backoff');% backoff
                         else %backoff resume
                             if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': frame ' num2str(entity.data.SN) ' resumes backoff!']);
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) '-------AC2 Backoff left:' num2str(obj.backoff_AC2) '----------']);                    
                             end
                           events=obj.hcfBfCont('AC2backoff',entity);    
%                             events=obj.eventTimer('AC0backoff',0);
                           obj.backoffPause=0;
                         end                                                      
                    else
                        events=obj.hcfListen(entity,'AC2Listen');
                    end
                case 'AC3AIFS'   
                    if hcfCS==0   %Channel free
                         if obj.backoffPause==0                              
                            %backoff start
    %                       disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': frame ' num2str(entity.data.SN) ' starts backoff!']);
                            events=obj.hcfBfStart(entity,'AC3backoff');% backoff
                         else
                           %backoff resume
                           if obj.txtEnable==1
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': frame ' num2str(entity.data.SN) ' resumes backoff!']);
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) '-------AC3 Backoff left:' num2str(obj.backoff_AC3) '----------']);                    
                           end
                           events=obj.hcfBfCont('AC3backoff',entity);     
%                             events=obj.eventTimer('AC0backoff',0);
                           obj.backoffPause=0;
                         end
                    else
                        events=obj.hcfListen(entity,'AC3Listen');
                    end
                %Backoff timer
                case 'AC0backoff'
%                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': Frame' num2str(entity.data.SN) ' backoff .......']);
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) '-------AC0 Backoff left:' num2str(obj.backoff_AC0) '----------']);                    
                    end
                        if obj.backoff_AC0==0 % backoff counter reach to zero, transmit immediatelly
                            if hcfCS==0
                                if entity.data.Retry==0
                                        events=obj.intContentionCheck(entity);
                                else                      
                                        [entity,events]=obj.extContentionCheck(entity);  
                                end    
                            else
                                obj.backoffPause=1;
                                events=obj.hcfListen(entity,'AC0Listen');
                            end
                            
                        else
                            if hcfCS==0  % Channel free, keep backoff 
                                events=obj.hcfBfCont(tag,entity);                        
                            else % Channel busy, pause backoff and listen
                                obj.backoffPause=1;
                                events=obj.hcfListen(entity,'AC0Listen');
                            end
                        end   
                case 'AC1backoff'
%                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ':  Frame' num2str(entity.data.SN) ' backoff .......']);
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) '-------AC1 Backoff left:' num2str(obj.backoff_AC1) '----------']);                    
                    end
                        if obj.backoff_AC1==0 % backoff counter reach to zero, transmit immediatelly
                            if hcfCS==0
                                if entity.data.Retry==0
                                        events=obj.intContentionCheck(entity);
                                else                      
                                        [entity,events]=obj.extContentionCheck(entity);  
                                end   
                            else
                                obj.backoffPause=1;
                                events=obj.hcfListen(entity,'AC1Listen');
                            end
                            
                        else
                            if hcfCS==0  % Channel free, keep backoff 
                                events=obj.hcfBfCont(tag,entity);                        
                            else % Channel busy, pause backoff and listen
                                obj.backoffPause=1;
                                events=obj.hcfListen(entity,'AC1Listen');
                            end
                        end   
                case 'AC2backoff'
%                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': Frame' num2str(entity.data.SN) ' backoff .......']);       
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) '-------AC2 Backoff left:' num2str(obj.backoff_AC2) '----------']);                    
                    end
                        if obj.backoff_AC2==0 % backoff counter reach to zero, transmit immediatelly
                            if hcfCS==0
                                if entity.data.Retry==0
                                        events=obj.intContentionCheck(entity);
                                else                      
                                        [entity,events]=obj.extContentionCheck(entity);  
                                end   
                            else % Channel busy, pause backoff and listen
                                obj.backoffPause=1;
                                events=obj.hcfListen(entity,'AC2Listen');
                            end
                            
                        else
                            if hcfCS==0  % Channel free, keep backoff 
                                events=obj.hcfBfCont(tag,entity);                        
                            else % Channel busy, pause backoff and listen
                                obj.backoffPause=1;
                                events=obj.hcfListen(entity,'AC2Listen');
                            end
                        end   
                case 'AC3backoff'
%                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': Frame' num2str(entity.data.SN) ' backoff .......']);
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) '-------AC3 Backoff left:' num2str(obj.backoff_AC3) '----------']);                    
                    end
                        if obj.backoff_AC3==0 % backoff counter reach to zero, transmit immediatelly
                            if hcfCS==0
                                if entity.data.Retry==0
                                        events=obj.intContentionCheck(entity);
                                else                      
                                        [entity,events]=obj.extContentionCheck(entity);  
                                end
                            else % Channel busy, pause backoff and listen
                                obj.backoffPause=1;
                                events=obj.hcfListen(entity,'AC3Listen');
                            end
                        else
                            if hcfCS==0  % Channel free, keep backoff 
                                events=obj.hcfBfCont(tag,entity);                        
                            else % Channel busy, pause backoff and listen
                                obj.backoffPause=1;
                                events=obj.hcfListen(entity,'AC3Listen');
                            end
                        end                       
                %Data transmission timer    
                case 'dataTx'                                                                      
                    events=obj.eventTimer('ackTimeout',obj.ackTimeout);  
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ' acktimeout set: ' num2str(obj.ackTimeout*1000) 'ms']);                   
                    end
                    obj.intContention=0;
                case 'ackTimeout'
                    assert(storage==7);
                    if obj.txtEnable==1
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': ACK' num2str(entity.data.SN) '  not received, start retransmission<<<<<<<<<<']);
                    end
                    disp(['(ackTimeout) entity.data.Address1 ' num2str(entity.data.Address1) 'entity.data.Address2 ' num2str(entity.data.Address2) 'entity.data.Address3 ' num2str(entity.data.Address3)]);
                    entity.data.Retry=1;
                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  node' num2str(obj.txAddr) ': Retry times  (ack Timeout)' num2str(entity.data.Retry)]);                
                    events=obj.hcfReTx(entity);
                case 'broadcast'
                    events=obj.eventDestroy();                   
                    obj.intContention=0;
            end            
        end
    end
    
    
end
