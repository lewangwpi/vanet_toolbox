classdef des_MAC_RSU<matlab.DiscreteEventSystem & matlab.system.mixin.Propagates & matlab.system.mixin.SampleTime   
    properties      
        Retry_MAX=3;
        % EDCA Parameters  
        
        AIFSN_AC0=9 % AIFSN_AC0
        AIFSN_AC1=6 % AIFSN_AC1
        AIFSN_AC2=3 % AIFSN_AC2
        AIFSN_AC3=2 % AIFSN_AC3
        
        aCWmin=15      
        aCWmax=1023
                
        slottime=0.000013 % Timeslot period (unit:s)
        sifs=0.000032 
        propTime=1; % Air propagation time (us)
        
        BSSID=00
%         txAddr=0; % Transmitter Address (txAddr) 
        rxAddr=0;  % Receiver(s) Address (rxAddr)
    end

    properties(DiscreteState)
        intContention
        extContention  % 0 is free                        
%         hcfCS          % Carrier sensing states: (0-free,1-busy) 
    end

    % Pre-computed constants
    properties(Access = private)
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
        
        isFirstAC0
        isFirstAC1
        isFirstAC2
        isFirstAC3
        
        numRx
        TxACTag
        
        RxDataSN
        RxACKSN
        
        ackTimeout
        waitForACK
        
        srcAddress % SA
        dstAddress % DA
        
        waveformBodyBuffer
        waveformSNBuffer
        waveformLengthBuffer
        
        dataTxDelay
        dataRxDelay
        ackTxRxDelay
        
        SIFS
        slotTime
        
        backoffPause
        timestampBuffer
    end

    methods(Access = protected)
        
        function setupImpl(obj)
            obj.SIFS=obj.sifs/1000000;
            obj.slotTime=obj.slottime/1000000;
            
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
            
            obj.CWmin_AC1=(obj.aCWmin+1)/2-1;
            obj.CWmax_AC1=obj.aCWmin;
            
            obj.CWmin_AC2=(obj.aCWmin+1)/4-1;
            obj.CWmax_AC2=(obj.aCWmin+1)/2-1;
            
            obj.CWmin_AC3=(obj.aCWmin+1)/4-1;
            obj.CWmax_AC3=(obj.aCWmin+1)/2-1;
            
            %Backoff timer for each AC
            obj.backoff_AC0=0;
            obj.backoff_AC1=0;
            obj.backoff_AC2=0;
            obj.backoff_AC3=0;
            %Define AIFS for each AC
            obj.AIFS_AC0=obj.AIFSN_AC0*obj.slotTime+obj.SIFS;
            obj.AIFS_AC1=obj.AIFSN_AC1*obj.slotTime+obj.SIFS;
            obj.AIFS_AC2=obj.AIFSN_AC2*obj.slotTime+obj.SIFS;
            obj.AIFS_AC3=obj.AIFSN_AC3*obj.slotTime+obj.SIFS;
            
            %txNum records transmission time of one frame in each AC queue
            obj.txNum_AC0=0;
            obj.txNum_AC1=0;
            obj.txNum_AC2=0;
            obj.txNum_AC3=0;
            
            obj.extContention=0; % External Contention
            obj.intContention=0; % Internal Contention
%             obj.hcfCS=0; % default: sleep    
            obj.waveformBodyBuffer=zeros(1535,1);
            obj.waveformSNBuffer=0;
            obj.waveformLengthBuffer=0;                        
            
            obj.dataTxDelay=0;  % dataTxDelay= length(data)/bitrate                        
            obj.dataRxDelay=0;
            obj.ackTxRxDelay=0;
%             ACK=macFrame();
%             obj.ackTimeout=2*obj.propTime/1000000+obj.SIFS+length(ACK.frameArray)/10000; 
            obj.ackTimeout=2*obj.propTime/1000000+obj.SIFS+975/10000000+1/1000000; 
            
            obj.isFirstAC0=1;
            obj.isFirstAC1=1;
            obj.isFirstAC2=1;
            obj.isFirstAC3=1;
            
            obj.backoffPause=0;
            obj.timestampBuffer=0;
        end
        
        function num=getNumInputsImpl(~)
            num=1;
        end
        
        function num=getNumOutputsImpl(~)
            num=1;
        end
        
        function [sz,dt,cp]=getDiscreteStateSpecificationImpl(obj,name)
            sz=[1,1];
            dt='double';
            cp=false;
        end
        
        function entityTypes=getEntityTypesImpl(obj)
            entityTypes=obj.entityType('waveform','Waveform');
        end
        
        function [inputTypes,outputTypes]=getEntityPortsImpl(obj)
            inputTypes='waveform';
            outputTypes='waveform';
        end
        
        function [storageSpecs,I,O]=getEntityStorageImpl(obj)
            storageSpecs=[obj.queueFIFO('waveform',inf)...  % Storage 1: Waveform Input
                          obj.queueFIFO('waveform',inf)...  % Storage 2: AC0
                          obj.queueFIFO('waveform',inf)...  % Storage 3: AC1
                          obj.queueFIFO('waveform',inf)...  % Storage 4: AC2
                          obj.queueFIFO('waveform',inf)...  % Storage 5: AC3
                          obj.queueFIFO('waveform',inf)...  % Storage 6: waveforms waiting for ACK in the storage
                          obj.queueFIFO('waveform',inf)];   % Storage 7: waveform output 
             I=1;
             O=7;
        end
        %%
        function [entity,events]=waveformEntryImpl(obj,storage,entity,source)      
%             disp('waveformentryimpl triggered');
            events=[];
            obj.dataTxDelay=length(entity.data.Body)/10000000;
            switch storage
                case 1
                     % Distinguish waveform type (Data/ACK) from BUS
                    if sum(entity.data.ACKBody)==0  % Receive Data
                        [ status, outframe, outmsg ] = phy_waveform2psdu(entity.data.Body,entity.data.SNR,entity.data.Length );                         
                    else                            % Receive ACK
                        [ status, outframe, outmsg ] = phy_waveform2psdu(entity.data.ACKBody,entity.data.SNR,entity.data.Length );                         
                    end
                    
                    if status==1                    
%                         disp([' AP: ToDS ' num2str(entity.data.ToDS) ' AP address ' num2str(entity.data.Address1) ' BSSID ' num2str(obj.BSSID)]);
                        if (entity.data.FromDS==0) && (entity.data.ToDS==1) && (entity.data.Address1==obj.BSSID)
                            switch outframe.typeField
                                case 1  % ACK Received
                                    if outframe.subtypeField==13     
%                                         disp(['AP: waitforACK' num2str(obj.waitForACK) '------------------------------------']);
                                        if ismember(entity.data.SN,obj.waitForACK) % Make sure the ACK is to the right data
                                            disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms'  ',  AP ' num2str(obj.BSSID) ':  ACK ' num2str(entity.data.SN) ' is intact. Prepare to send next...']);                            
                                            obj.RxACKSN=entity.data.SN;
                                            events=[obj.eventIterate(6,'ackOK',1)...
                                            obj.eventDestroy()];
                                            obj.waitForACK=obj.waitForACK(obj.waitForACK~=entity.data.SN);
                                        else  % ACK is not to the right data
                                            disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms' ',  AP ' num2str(obj.BSSID) ': Invalide ACK: SN does not match, discard!']); %
                                            events=obj.eventDestroy();
                                        end                                                                                                                             
                                    else
                                        disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms' ',  AP ' num2str(obj.BSSID) ': This is not an ACK frame']);
                                        events=obj.eventDestroy();
                                    end                                                                      
                                    
                                case 2  % Data     
                                    obj.timestampBuffer=entity.data.Timestamp;
                                    obj.srcAddress=entity.data.Address2;
                                    obj.dstAddress=entity.data.Address3;
%                                     disp(['AP ' num2str(obj.BSSID) ': ' ' srcAdd ' num2str(obj.srcAddress) ' dstAdd ' num2str(obj.dstAddress)]);
                                    if entity.data.Address3==0 % Broadcast waveform
                                        disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms' ', AP' num2str(obj.BSSID) 'this is a broadcast message, ack not needed']);                                        
                                    else
                                        obj.RxDataSN=entity.data.SN;
                                        disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms' ', AP' num2str(obj.BSSID) ': receive message ' num2str(entity.data.SN) ' from node' num2str(entity.data.Address3) 'to node ' num2str(entity.data.Address2) ', generate ACK']);                                        
                                        events=obj.eventGenerate(7,'sendACK',obj.SIFS,1);
                                    end
                                                                                                                                                    
                                    switch entity.data.ACTag
                                        case 0                                            
                                            events=[events obj.eventForward('storage',2,0)];
                                        case 1
                                            events=[events obj.eventForward('storage',3,0)];
                                        case 2
                                            events=[events obj.eventForward('storage',4,0)];
                                        case 3
                                            events=[events obj.eventForward('storage',5,0)];
                                    end 
%                                     obj.numRx=obj.numRx-1;
                                otherwise
                                    disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms' ', AP' num2str(obj.BSSID) ': Data type unidentified!']);
                                    events=[events obj.eventDestroy()];                                                                                                         
                            end                            
                        else
                            disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms' ', AP' num2str(obj.BSSID) ': The received frame is not for me, discard!']);
                            events=obj.eventDestroy();
                        end                        
                    else
                        disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms'  ',  AP' num2str(obj.BSSID) ': ' outmsg '--> destroyed!']);
                        events=obj.eventDestroy();
                    end
                                                         
                    
                case 2 %AC0
%                     disp(['AP ' num2str(obj.SSID) ': ' ]);
%                     disp('entity enters AC0');
                    obj.numFrame_AC0=obj.numFrame_AC0+1;
                    if obj.numFrame_AC0==1 && obj.isFirstAC0
                        events=obj.hcfListen(entity,'AC0Listen');
%                         events=obj.hcfBfStart(entity,'AC0backoff');% backoff
                        obj.isFirstAC0=0;
                    end 
                case 3 %AC1
%                     disp('entity enters AC1');
                    obj.numFrame_AC1=obj.numFrame_AC1+1;
                    if obj.numFrame_AC1==1 && obj.isFirstAC1
                        events=obj.hcfListen(entity,'AC1Listen');
%                         events=obj.hcfBfStart(entity,'AC1backoff');% backoff
                        obj.isFirstAC1=0;
                    end
                case 4 %AC2
%                     disp('entity enters AC2');
                    obj.numFrame_AC2=obj.numFrame_AC2+1;
                    if obj.numFrame_AC2==1 && obj.isFirstAC2
                        events=obj.hcfListen(entity,'AC2Listen');
%                         events=obj.hcfBfStart(entity,'AC2backoff');% backoff
                        obj.isFirstAC2=0;
                    end
                case 5 %AC3
                    disp('entity enters AC3');
                    disp(['Init AC3' num2str(obj.numFrame_AC3)]);
                    obj.numFrame_AC3=obj.numFrame_AC3+1;
                    if obj.numFrame_AC3==1 && obj.isFirstAC3
                        events=obj.hcfListen(entity,'AC3Listen');
%                         events=obj.hcfBfStart(entity,'AC3backoff');% backoff
                        obj.isFirstAC3=0;
                    end
                case 6 %Wait for ACK field
%                     disp(['AP ' num2str(obj.BSSID) 'waveform enters storage 6']);
                    obj.intContention=1;
                    [entity,events]=obj.extContentionCheck(entity);
            end        
        end
        
        function [entity,events]=waveformTimerImpl(obj,storage,entity,tag)
            events=[];
            hcfCS=phy_ChannelSensing(1,0,0); % Channel sensing
            switch tag
                case {'AC0Listen','AC1Listen','AC2Listen','AC3Listen'}                       
                    events=obj.hcfListen(entity,tag);               
                case 'AC0AIFS'                    
                    if hcfCS==0  %Channel free
                        if obj.backoffPause==0   % new backoff 
    %                       disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ': frame ' num2str(entity.data.SN) ' starts backoff!']);
                            events=obj.hcfBfStart(entity,'AC0backoff');% backoff
                        else % resume backoff 
                           disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ': frame ' num2str(entity.data.SN) ' resumes backoff!']);
                           disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) '-------AC0 Backoff left:' num2str(obj.backoff_AC0) '----------']);                    
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
    %                       disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ': frame ' num2str(entity.data.SN) ' starts backoff!']);
                            events=obj.hcfBfStart(entity,'AC1backoff');% backoff
                         else
                           %backoff resume
                           disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ': frame ' num2str(entity.data.SN) ' resumes backoff!']);
                           disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) '-------AC1 Backoff left:' num2str(obj.backoff_AC1) '----------']);                    
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
    %                       disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ': frame ' num2str(entity.data.SN) ' starts backoff!']);
                            events=obj.hcfBfStart(entity,'AC2backoff');% backoff
                         else %backoff resume
                           disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ': frame ' num2str(entity.data.SN) ' resumes backoff!']);
                           disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) '-------AC2 Backoff left:' num2str(obj.backoff_AC2) '----------']);                    
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
    %                       disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ': frame ' num2str(entity.data.SN) ' starts backoff!']);
                            events=obj.hcfBfStart(entity,'AC3backoff');% backoff
                         else
                           %backoff resume
                           disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ': frame ' num2str(entity.data.SN) ' resumes backoff!']);
                           disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) '-------AC3 Backoff left:' num2str(obj.backoff_AC3) '----------']);                    
                           events=obj.hcfBfCont('AC3backoff',entity);     
%                             events=obj.eventTimer('AC0backoff',0);
                           obj.backoffPause=0;
                         end
                    else
                        events=obj.hcfListen(entity,'AC3Listen');
                    end

                %Backoff timer 
              case 'AC0backoff'
%                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ': Frame' num2str(entity.data.SN) ' backoff .......']);
                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) '-------AC0 Backoff left:' num2str(obj.backoff_AC0) '----------']);                    
                        if obj.backoff_AC0==0 % backoff counter reach to zero, transmit immediatelly
                            if entity.data.Retry==0
                                    events=obj.intContentionCheck(entity);
                            else                      
                                    [entity,events]=obj.extContentionCheck(entity);  
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
%                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  Frame' num2str(entity.data.SN) ' backoff .......']);
                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) '-------AC1 Backoff left:' num2str(obj.backoff_AC1) '----------']);                    
                        if obj.backoff_AC1==0 % backoff counter reach to zero, transmit immediatelly
                            if entity.data.Retry==0
                                    events=obj.intContentionCheck(entity);
                            else                      
                                    [entity,events]=obj.extContentionCheck(entity);  
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
%                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ': Frame' num2str(entity.data.SN) ' backoff .......']);       
                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) '-------AC2 Backoff left:' num2str(obj.backoff_AC2) '----------']);                    
                        if obj.backoff_AC2==0 % backoff counter reach to zero, transmit immediatelly
                            if entity.data.Retry==0
                                    events=obj.intContentionCheck(entity);
                            else                      
                                    [entity,events]=obj.extContentionCheck(entity);  
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
%                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ': Frame' num2str(entity.data.SN) ' backoff .......']);
                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) '-------AC3 Backoff left:' num2str(obj.backoff_AC3) '----------']);                    
                        if obj.backoff_AC3==0 % backoff counter reach to zero, transmit immediatelly
                            if entity.data.Retry==0
                                    events=obj.intContentionCheck(entity);
                            else                      
                                    [entity,events]=obj.extContentionCheck(entity);  
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
                    if obj.dstAddress~=0
                        disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms'  ',  AP ' num2str(obj.BSSID)  ':  transmission over, wait for ACK <<--']);
                        obj.intContention=0;
%                         actTimeout=0.35;               % actTimeout should be calculated from 'prop time and sample rate'.
                        events=obj.eventTimer('ackTimeout',obj.ackTimeout);  
                    else
                        disp('Dst address is 0, broadcast! No ack required.');
                        obj.intContention=0;
                        events=obj.eventDestroy(); %%@@
                        obj.waitForACK=obj.waitForACK(obj.waitForACK~=entity.data.SN);
                    end
                    
                case 'ackTimeout'
                    disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms'  ',  AP ' num2str(obj.BSSID) ': ACK' num2str(entity.data.SN) '  not received, start retransmission<<<<<<<<<<']);
                    events=obj.hcfReTx(entity);
                    
                case 'broadcast'
                    events=obj.eventDestroy();                   
                    obj.intContention=0;
                   
            end                                    
        end
        
        
        function [entity,events]=waveformGenerateImpl(obj,storage,entity,tag)
            obj.extContention=1;
            entity.data.FromDS=1;
            entity.data.ToDS=0;
%             disp('AP: Waveformgenerateimpl triggered!');
            switch tag
                case 'sendACK'              % send ack
                    entity.data.Control=13;
                    entity.data.Address1=obj.srcAddress;
                    entity.data.Address2=obj.BSSID;
                    entity.data.Address3=obj.dstAddress;                    
                    entity.data.SN=obj.RxDataSN;
%                     disp(['AP ' num2str(obj.BSSID) ': ' ' add1 ' num2str(entity.data.Address1) ' add2 ' num2str(entity.data.Address2) ' add3 ' num2str(entity.data.Address3)]);
                    [entity.data.ACKBody,entity.data.Length]=phy_psdu2waveform(1,obj.srcAddress);  
                    events=obj.eventForward('output',1,0);
                
                otherwise                   % send data
                    
                    entity.data.Control=8;
                    entity.data.Address1=obj.dstAddress;
                    entity.data.Address2=obj.BSSID;
                    entity.data.Address3=obj.srcAddress;
                    entity.data.SN=obj.waveformSNBuffer;       
%                     [waveform,entity.data.Length]=phy_psdu2waveform(0,obj.BSSID,obj.dstAddress,obj.waveformBodyBuffer); 
                    entity.data.Length=obj.waveformLengthBuffer;
                    entity.data.Body=obj.waveformBodyBuffer; 
                    entity.data.Timestamp=obj.timestampBuffer;
                    switch tag
                        case 'sendFrame_AC0'
                            entity.data.ACTag=0;
                        case 'sendFrame_AC1'
                            entity.data.ACTag=1;
                        case 'sendFrame_AC2'
                            entity.data.ACTag=2;
                        case 'sendFrame_AC3'
                            entity.data.ACTag=3;
                    end                  
                    events=obj.eventForward('output',1,0);
            end           
        end
        
        function events=waveformExitImpl(obj,storage,entity,src)
            events=[];
            if storage ==7
                obj.extContention=0;
                obj.intContention=0;
                if entity.data.Control==8
                    disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms'  ',  AP ' num2str(obj.BSSID) ':  waveform' num2str(entity.data.SN) ' is sending...'])
                elseif entity.data.Control==13
                    disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms'  ',  AP ' num2str(obj.BSSID) ':  ACK' num2str(entity.data.SN) ' is sending...'])
                end                                
            end
        end
        
        function [entity,events,next]=waveformIterateImpl(obj,storage,entity,tag,cur)
            events=[];
            switch tag
                case 'ackOK'
                    if entity.data.SN==obj.RxACKSN
                        switch entity.data.ACTag
                            case 0
%                                 disp('Frame from AC0 is destroyed');
                                if obj.numFrame_AC0>=1
                                    events=obj.eventIterate(2,'nextAC0',10);
                                else
                                    disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms'  ',  AP ' num2str(obj.BSSID) ': no more frames in AC0...']);
                                    obj.isFirstAC0=1;
                                end
                            case 1
%                                 disp('Frame from AC1 is destroyed')
                                if obj.numFrame_AC1>=1
                                    events=obj.eventIterate(3,'nextAC1',10);
                                else
                                    disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms'  ',  AP ' num2str(obj.BSSID) ': no more frames in AC1...']);
                                    obj.isFirstAC1=1;
                                end
                            case 2
%                                 disp('frame from AC2 is destroyed');
                                if obj.numFrame_AC2>=1
                                    events=obj.eventIterate(4,'nextAC2',10);
                                else
                                    disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms'  ',  AP ' num2str(obj.BSSID) ': no more frames in AC2...']);
                                    obj.isFirstAC2=1;
                                end
                                
                            case 3
%                                 disp(['frame from AC3 is destroyed' num2str(obj.numFrame_AC3)]);
                                if obj.numFrame_AC3>=1
                                    events=obj.eventIterate(5,'nextAC3',10);
                                else
                                    disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms'  ',  AP ' num2str(obj.BSSID) ': no more frames in AC3...']);
                                    obj.isFirstAC3=1;
                                end
                        end
                        events=[events obj.eventDestroy()];
                        next=false;
                    else
                        events=[];
                        next=true;
                    end
                case 'nextAC0'
                    disp('Iterate AC0');   
                    if cur.position==1
                        events=obj.hcfListen(entity, 'AC0Listen');
                        next=false;
                    end
                case 'nextAC1'
                    disp('Iterate AC1');
                    if cur.position==1
                        events=obj.hcfListen(entity, 'AC1Listen');
                        next=false;  
                    end
                case 'nextAC2'
                    disp('Iterate AC2');
                    if cur.position==1
                        events=obj.hcfListen(entity, 'AC2Listen');
                        next=false;
                    end
                case 'nextAC3'
                    disp('Iterate AC3');
                    if cur.position==1
                        events=obj.hcfListen(entity, 'AC3Listen');
                        next=false;
                    end                        
            end                                                                   
        end
        
       %% Self-defined function
        % Listen - if channel is idle. 
        % Listen period -- AIFS
        % tag - AC0Listen <-> AC3Listen;
        function events=hcfListen(obj,entity,tag)
%             disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  frame(AC' num2str(entity.data.ACTag) ')' num2str(entity.data.SN) ' start listening.']);
            hcfCS=phy_ChannelSensing(1,0,0); % Channel sensing
            if hcfCS==0  %Channel busy                
                switch tag
                    case 'AC0Listen'
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  frame' num2str(entity.data.SN) '(AC' num2str(entity.data.ACTag) ...
                            ')' ' sense idle channel, defer access AIFS_AC0 ' num2str(obj.AIFS_AC0*1000) 'ms']);%defer access to AIFS
                        events=obj.eventTimer('AC0AIFS',obj.AIFS_AC0);
                    case 'AC1Listen'
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  frame' num2str(entity.data.SN) '(AC' num2str(entity.data.ACTag) ...
                            ')'  ' sense idle channel, defer access AIFS_AC1 ' num2str(obj.AIFS_AC1*1000) 'ms']);%defer access to AIFS
                        events=obj.eventTimer('AC1AIFS',obj.AIFS_AC1);
                    case 'AC2Listen'
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  frame' num2str(entity.data.SN) '(AC' num2str(entity.data.ACTag) ...
                            ')'  ' sense idle channel, defer access AIFS_AC2 ' num2str(obj.AIFS_AC2*1000) 'ms']);%defer access to AIFS
                        events=obj.eventTimer('AC2AIFS',obj.AIFS_AC2);
                    case 'AC3Listen'
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  frame' num2str(entity.data.SN) '(AC' num2str(entity.data.ACTag) ...
                            ')'  ' sense idle channel, defer access AIFS_AC3 ' num2str(obj.AIFS_AC3*1000) 'ms']);%defer access to AIFS
                        events=obj.eventTimer('AC3AIFS',obj.AIFS_AC3);
                end                
            else
                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  frame' num2str(entity.data.SN) '(AC' num2str(entity.data.ACTag) ...
                            ')'  ' sense busy channel, listen to another slottime ' num2str(obj.slotTime*1000) 'ms']);%defer access to AIFS
                events=obj.eventTimer(tag,obj.slotTime);% Listen                
            end  
        end

        
        function events=hcfBfStart(obj,entity,tag)                       
                    switch tag
                        case 'AC0backoff'                            
                            obj.backoff_AC0=randi([0 obj.CWmin_AC0]);
                            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  Frame ' num2str(entity.data.SN) ' (AC0) listen idle channel, backoff ' num2str(obj.backoff_AC0) ' timeslots;']);
                            if obj.backoff_AC0==0
                                if entity.data.Retry==0
                                    events=obj.intContentionCheck(entity);
                                else                      
                                    [entity,events]=obj.extContentionCheck(entity);  
                                end 
                            else
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) '-------AC0 Backoff left:' num2str(obj.backoff_AC0) '----------']);                    
                                obj.backoff_AC0=obj.backoff_AC0-1;
                                events=obj.eventTimer(tag,obj.slotTime); 
                            end                                                                                    
                        case 'AC1backoff'
                            obj.backoff_AC1=randi([ 0 obj.CWmin_AC1]);
                            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  Frame ' num2str(entity.data.SN) '(AC1) listen idle channel,backoff ' num2str(obj.backoff_AC1) ' timeslots;']);
                            if obj.backoff_AC1==0
                                if entity.data.Retry==0
                                    events=obj.intContentionCheck(entity);
                                else                      
                                    [entity,events]=obj.extContentionCheck(entity);  
                                end 
                            else
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) '-------AC1 Backoff left:' num2str(obj.backoff_AC1) '----------']);                    
                                obj.backoff_AC1=obj.backoff_AC1-1;
                                events=obj.eventTimer(tag,obj.slotTime); 
                            end
                            
                            
                        case 'AC2backoff'
                            obj.backoff_AC2=randi([0 obj.CWmin_AC2]);
                            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  Frame ' num2str(entity.data.SN) '(AC2) listen idle channel,backoff ' num2str(obj.backoff_AC2) ' timeslots;']);
                            if obj.backoff_AC2==0
                                if entity.data.Retry==0
                                    events=obj.intContentionCheck(entity);
                                else                      
                                    [entity,events]=obj.extContentionCheck(entity);  
                                end 
                            else
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) '-------AC2 Backoff left:' num2str(obj.backoff_AC2) '----------']);                    
                                obj.backoff_AC2=obj.backoff_AC2-1;
                                events=obj.eventTimer(tag,obj.slotTime); 
                            end
                            
                            
                        case 'AC3backoff'
                            obj.backoff_AC3=randi([0 obj.CWmin_AC3]);
                            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  Frame ' num2str(entity.data.SN) '(AC3) listen idle channel,backoff ' num2str(obj.backoff_AC3) ' timeslots;']);
                            if obj.backoff_AC3==0
                                if entity.data.Retry==0
                                    events=obj.intContentionCheck(entity);
                                else                      
                                    [entity,events]=obj.extContentionCheck(entity);  
                                end 
                            else
                                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) '-------AC3 Backoff left:' num2str(obj.backoff_AC3) '----------']);                    
                                obj.backoff_AC3=obj.backoff_AC3-1;
                                events=obj.eventTimer(tag,obj.slotTime); 
                            end                                                        
                    end
                                   
        end
        
        % BackoffContinue called during backoff process AIFS by AIFS;
        % If backoff decrease to Zero, call internal Contention check;
        function events=hcfBfCont(obj,tag,entity)
            events=[];
            switch tag
                case 'AC0backoff' 
                    if obj.backoff_AC0==0
                                if entity.data.Retry==0
                                    events=obj.intContentionCheck(entity);
                                else                      
                                    [entity,events]=obj.extContentionCheck(entity);  
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
                                    [entity,events]=obj.extContentionCheck(entity);  
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
                                    [entity,events]=obj.extContentionCheck(entity);  
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
                                    [entity,events]=obj.extContentionCheck(entity);  
                                end 
                    else
                        obj.backoff_AC3=obj.backoff_AC3-1;
                        events=obj.eventTimer(tag,obj.slotTime);
                    end
            end        
        end
        
        % Internal Contention Check
        % If internal contention exist, restart backoff
        % if no internal contention, forward 'Frame Entity' to 'HCF
        % Storage';
        function events=intContentionCheck(obj,entity)
            if obj.intContention==0
                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  Internal Contention Not Detected! Send to Tx Buffer......'])
                events=obj.eventForward('storage',6,0); %Forward to Tx buffer, storage 6
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
                        disp(['UPdated numFrame_ac3' num2str(obj.numFrame_AC3)]);
                end                
            else
                disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':   Internal Contention Detected! Redo backoff .....@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.']);
                events=obj.hcfReTx(entity);
            end
        end
        
        % External Check 
        % Task 1: Channel sensing, check if incoming transmission exist;
        % Task 2: Check is current AP is transmitting;
        % Task 3: Buff the Sequence Number of packets awaiting sending.
        % Generate 'Waveform entity' in STORAGE 8; Create 'dataTx' timer
        % for simulating transmission delay.
        % If channel is busy or the current AP is transmitting, redo backoff 
        function [entity,events]=extContentionCheck(obj,entity)
            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  retry times (extCon)' num2str(entity.data.Retry)]);                           
            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  External Contention NOT Detected! Send to Tx output......']);
%             disp(['dataTxDelay ' num2str(obj.dataTxDelay)]);                                    
                
                obj.waveformBodyBuffer=entity.data.Body;
                obj.waveformLengthBuffer=entity.data.Length;
                obj.TxACTag=entity.data.ACTag;                                                                                        
                obj.srcAddress=entity.data.Address2;
                obj.dstAddress=entity.data.Address3;
                
                                    
                    
                if obj.dstAddress~=0 % Unicast
                    disp('This is Unicast');
                    obj.waveformSNBuffer=entity.data.SN;
                    if ~ismember(obj.waveformSNBuffer,obj.waitForACK)
                        obj.waitForACK=[obj.waitForACK obj.waveformSNBuffer];
                    end
                                        
                    switch entity.data.ACTag
                        case 0
                            events=[obj.eventGenerate(7,'sendFrame_AC0',0,1) obj.eventTimer('dataTx',obj.dataTxDelay)];
                        case 1
                            events=[obj.eventGenerate(7,'sendFrame_AC1',0,1) obj.eventTimer('dataTx',obj.dataTxDelay)];
                        case 2
                            events=[obj.eventGenerate(7,'sendFrame_AC2',0,1) obj.eventTimer('dataTx',obj.dataTxDelay)];
                        case 3
                            events=[obj.eventGenerate(7,'sendFrame_AC3',0,1) obj.eventTimer('dataTx',obj.dataTxDelay)];
%                             events=obj.eventGenerate(7,'sendFrame_AC3',0,10);                            
                    end                                                            
                else  % Broadcast 
                    disp('This is BroadCast');
                    obj.waveformSNBuffer=entity.data.SN;
                    switch entity.data.ACTag
                        case 0
                            events=[obj.eventGenerate(7,'sendFrame_AC0',obj.dataTxDelay,1) obj.eventDestroy()];
                            if obj.numFrame_AC0>=1
                                    events=[events obj.eventIterate(2,'nextAC0',10)];
                            else
                                disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms'  ',  AP ' num2str(obj.BSSID) ': no more frames in AC0...']);
                                obj.isFirstAC0=1;
                            end
                        case 1
                            events=[obj.eventGenerate(7,'sendFrame_AC1',obj.dataTxDelay,1) obj.eventDestroy()];
                            if obj.numFrame_AC1>=1
                                    events=[events obj.eventIterate(3,'nextAC1',10)];
                            else
                                disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms'  ',  AP ' num2str(obj.BSSID) ': no more frames in AC1...']);
                                obj.isFirstAC1=1;
                            end
                        case 2
                            events=[obj.eventGenerate(7,'sendFrame_AC2',obj.dataTxDelay,1) obj.eventDestroy()];
                            if obj.numFrame_AC2>=1
                                    events=[events obj.eventIterate(4,'nextAC2',10)];
                            else
                                disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms'  ',  AP ' num2str(obj.BSSID) ': no more frames in AC2...']);
                                obj.isFirstAC2=1;
                            end
                        case 3
                            events=[obj.eventGenerate(7,'sendFrame_AC3',obj.dataTxDelay,1) obj.eventDestroy()];
                            if obj.numFrame_AC3>=1
                                    events=[events obj.eventIterate(5,'nextAC3',10)];
                            else
                                disp(['T= ' num2str(obj.getCurrentTime()*1000)  'ms'  ',  AP ' num2str(obj.BSSID) ': no more frames in AC3...']);
                                obj.isFirstAC3=1;
                            end
%                             events=[obj.eventGenerate(7,'sendFrame_AC3',0,1) obj.eventDestroy()];
                    end                                       
                end
                
        end
        
        % Rebackoff happens when: 1. media is busy after last backoff (internal contention or external contention); 2. ACK not
        % received.
        % Duty: Double CWmin. Restart from 'Listen' stage.
        function events=hcfReBf(obj,entity)
%             disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  retry times (hcfReBf)' num2str(entity.data.Retry)]);                
            events=[];
            switch entity.data.ACTag
                case 0
                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  rebackoff frame ' num2str(entity.data.SN)] );
                    if obj.CWmin_AC0*2<obj.CWmax_AC0
                        obj.CWmin_AC0=obj.CWmin_AC0*2;
                    else
                        obj.CWmin_AC0=obj.CWmax_AC0;
                    end
                    events=obj.hcfListen(entity, 'AC0Listen');
                case 1
                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  rebackoff frame ' num2str(entity.data.SN)] );
                    if obj.CWmin_AC1*2<obj.CWmax_AC1
                        obj.CWmin_AC1=obj.CWmin_AC1*2;
                    else
                        obj.CWmin_AC1=obj.CWmax_AC1;
                    end
                    events=obj.hcfListen(entity, 'AC1Listen');
                case 2
                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  rebackoff frame ' num2str(entity.data.SN)] );
                    if obj.CWmin_AC2*2<obj.CWmax_AC2
                        obj.CWmin_AC2=obj.CWmin_AC2*2;
                    else
                        obj.CWmin_AC2=obj.CWmax_AC2;
                    end
                    events=obj.hcfListen(entity, 'AC2Listen');
                case 3
                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  rebackoff frame ' num2str(entity.data.SN)] );
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
            events=[];
            switch entity.data.ACTag
                case 0
                    if obj.txNum_AC0==(obj.Retry_MAX+1)      %Retrans time more than 3, drop
                        obj.txNum_AC0=0;                    % Reset transmision times
                        obj.CWmin_AC0=obj.aCWmin;           % Reset CWmin
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  retransmit 3 times, dropped, send next.']);
                        %vanetUI(obj.isUIon,obj.getCurrentTime(),'drop',entity.data.ACTag);
                        
                        disp(['^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^SN ' num2str(entity.data.SN) ' waitforACK: ' num2str(obj.waitForACK) '^^^^^^^^^^^^^^^^^^^^^^']);
                        
                         if ismember(entity.data.SN,obj.waitForACK) % Make sure the ACK is to the right data                                                                                               
                            obj.waitForACK=obj.waitForACK(obj.waitForACK~=entity.data.SN);
                         end
                        
                        if obj.numFrame_AC0>1               % If more packets are waiting, prepare to send next;
                            events=obj.eventIterate(3,'nextAC0',1);
                        else                                % If no packets in the AC queue, stay sleep;
%                             events=obj.hcfSleep();
                            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  has no more frames in AC' num2str(entity.data.ACTag) ' stored']);
                        end
                        events=[events obj.eventDestroy()];
                    else 
                        obj.txNum_AC0=obj.txNum_AC0+1;      % Transmission times increases by 1
%                         entity.data.Retry=1;
                        events=obj.hcfReBf(entity);         % Redo backoff 
                    end
                case 1
                    if obj.txNum_AC1==(obj.Retry_MAX+1)      %Retrans time more than 3, drop
                        obj.txNum_AC1=0;
                        obj.CWmin_AC1=obj.aCWmin;                        
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ': retransmit 3 times, dropped, send next.']);
                        %vanetUI(obj.isUIon,obj.getCurrentTime(),'drop',entity.data.ACTag);
                        disp(['^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^SN ' num2str(entity.data.SN) ' waitforACK: ' num2str(obj.waitForACK) '^^^^^^^^^^^^^^^^^^^^^^']);
                        if ismember(entity.data.SN,obj.waitForACK) % Make sure the ACK is to the right data                                                                                               
                            obj.waitForACK=obj.waitForACK(obj.waitForACK~=entity.data.SN);
                         end
                        if obj.numFrame_AC1>1
                            events=obj.eventIterate(4,'nextAC1',1);
                        else
%                             events=obj.hcfSleep();
                            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ': has no more frames in AC' num2str(entity.data.ACTag) ' stored']);
                        end
                        events=[events obj.eventDestroy()];
                    else 
                        obj.txNum_AC1=obj.txNum_AC1+1;
%                         entity.data.Retry=1;
                        events=obj.hcfReBf(entity);
                    end
                case 2
                    if obj.txNum_AC2==(obj.Retry_MAX+1)      %Retrans time more than 3, drop
                        obj.txNum_AC2=0;
                        obj.CWmin_AC2=obj.aCWmin;                        
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ': retransmit 3 times, dropped, send next.']);
                        %vanetUI(obj.isUIon,obj.getCurrentTime(),'drop',entity.data.ACTag);
                        disp(['^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^SN ' num2str(entity.data.SN) ' waitforACK: ' num2str(obj.waitForACK) '^^^^^^^^^^^^^^^^^^^^^^']);
                        if ismember(entity.data.SN,obj.waitForACK) % Make sure the ACK is to the right data                                                                                               
                            obj.waitForACK=obj.waitForACK(obj.waitForACK~=entity.data.SN);
                         end
                        if obj.numFrame_AC2>1
                            events=obj.eventIterate(5,'nextAC2',1);
                        else
%                             events=obj.hcfSleep();                            
                            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ': AP' num2str(obj.BSSID) ' has no more frames in AC' num2str(entity.data.ACTag) ' stored']);
                        end
                        events=[events obj.eventDestroy()];
                    else 
                        obj.txNum_AC2=obj.txNum_AC2+1;
%                         entity.data.Retry=1;
                        events=obj.hcfReBf(entity);
                    end
                case 3
                    if obj.txNum_AC3==(obj.Retry_MAX+1)     %Retrans time more than 3, drop
                        obj.txNum_AC3=0;
                        obj.CWmin_AC3=obj.aCWmin;                        
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ': retransmit 3 times, dropped, send next.']);
                        %vanetUI(obj.isUIon,obj.getCurrentTime(),'drop',entity.data.ACTag);
                        disp(['^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^SN ' num2str(entity.data.SN) ' waitforACK: ' num2str(obj.waitForACK) '^^^^^^^^^^^^^^^^^^^^^^']);
                        if ismember(entity.data.SN,obj.waitForACK) % Make sure the ACK is to the right data                                                                                               
                            obj.waitForACK=obj.waitForACK(obj.waitForACK~=entity.data.SN);
                        end
%                         disp(['Updated WaitforACK ' num2str(obj.waitForACK)]); 
                        if obj.numFrame_AC3>1
                            events=obj.eventIterate(6,'nextAC3',1);
                        else
%                             events=obj.hcfSleep();
                            disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms' ',  AP' num2str(obj.BSSID) ':  has no more frames in AC' num2str(entity.data.ACTag) ' stored']);
                        end
                        events=[events obj.eventDestroy()];
                    else                          
                        obj.txNum_AC3=obj.txNum_AC3+1;
%                         entity.data.Retry=1;
                        events=obj.hcfReBf(entity);
                    end
            end
                
        end     
        
%         %% Self-defined methods
%         function events=hcfSleep(obj)
%             obj.extContention=0;
%             events=[];
%         end
        
    end
end
