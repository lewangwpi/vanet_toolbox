classdef des_APP_WME < matlab.DiscreteEventSystem & matlab.system.mixin.Propagates & matlab.system.mixin.SampleTime      
    % Untitled3 Add summary here
    %
    % This template includes the minimum set of functions required
    % to define a Discrete Event System object.

    % Public, tunable properties
    properties
        vehicleID = 0;
        enCCHIext = 0; % Enable CCHI_Extension
    end

    properties(DiscreteState)

    end

    % Pre-computed constants
    properties(Access = private)
        SCHStatus = zeros(1,6);
        chosenSCH = 0;
        onehopSCHinfo = 0;
        
        mcStatus=zeros(1,3);
        multiChannelSwitch = 0;
        
        SCHcount = 0;
    end

    % Discrete-event algorithms
    methods
        
                
        function events=setupEvents(obj)            
            events=obj.initEventArray;                         
            events = [events obj.eventGenerate(1,'initTIentity',0,300)];
        end
        
        function [entity,events] = entry(obj,storage,entity,source)
            coder.extrinsic('num2str');
            events = obj.initEventArray;
           
            % Specify event actions when entity enters storage    
%             disp(['receive channel coordination message from APP data plane']);
            switch entity.data.type
                case 1 % multichannel status update 
                    events = obj.updateChannelStatus(entity);
                case 2 % multichannel status inquiry                     
                    events = obj.selectSCH();                    
%                 case 3 % multichannel status release message
%                     events = obj.releaseSCH(entity);       
                
            end
        end
        
        function [entity,events] = mgmFrameGenerate(obj,storage,entity,tag)
            coder.extrinsic('num2str');
            events = obj.initEventArray;
            switch tag
                case 'initTIentity'
                    obj.mcStatus(1) = 1;
                    [events ,obj.multiChannelSwitch] = obj.mcCheck(obj.mcStatus);
                    
                case 'MCinfoReply'                    
                    entity.data.type = 4; % type 4, reply to APP data plane about chosen SCH
                    entity.data.field1 = obj.chosenSCH;                    
                    disp(['    Vehicle' num2str(obj.vehicleID)  '_WME replies APP layer --> SCH ' num2str(obj.chosenSCH)]);
                    events = obj.eventForward('output',1,0);
%                     events = [obj.eventGenerate(1,'createWBSS',0,300), obj.eventForward('output',1,0)];
%                 case 'createWBSS'
%                     entity.data.type = 5; % type 5, mgm msg to MLMEext to coordinate Multi-MAC configuration                    
%                     entity.data.field1 = obj.chosenSCH;
%                     disp(['    Vehicle' num2str(obj.vehicleID) '_WME creates WBSS on SCH ' num2str(entity.data.field1)]);
%                     events = obj.eventForward('output',2,0);  
%                 case 'joinWBSS'
%                     entity.data.type = 5; % type 5, mgm msg to MLMEext to coordinate Multi-MAC configuration         
%                     entity.data.field1 = obj.onehopSCHinfo;
%                     disp(['    Vehicle' num2str(obj.vehicleID) '_WME sends MAC management frame to MAC' num2str(entity.data.field1)]);
%                     events = obj.eventForward('output',2,0);
%                 case 'resetMCinfo'
%                     entity.data.type = 5; % type 5, mgm msg to MLMEext to coordinate Multi-MAC configuration         
%                     entity.data.field1 = 0;
%                     disp(['    Vehicle' num2str(obj.vehicleID) '_WME sends reset MC info message_' ]);
%                     events = obj.eventForward('output',2,0);
                case 'test'
                    entity.data.type = 5;
                    entity.data.field1 = obj.multiChannelSwitch;
                    events = obj.eventForward('output',2,0);
%                     disp(num2str(entity.data.field1));
            end
        end
        
        function [entity, events] = mgmFrameTimer(obj,storage,entity,tag)
            coder.extrinsic('num2str');
            events = obj.initEventArray;            
            switch tag
                case 'GI'
                    obj.mcStatus(1) = 0;
                                              
                case 'CCHI'  
                    if obj.enCCHIext == 0 || obj.chosenSCH ~= 0 || obj.onehopSCHinfo ~= 0 % SCH channel required, enter GI period
                        obj.mcStatus(1) = 1; 
                        obj.mcStatus(2) = 1; %[1,1,0] SCH Guard Interval
                        obj.mcStatus(3) = 0;
                    else               % SCH service not detected, stay in CCH_MAC
                        obj.mcStatus(1) = 0; 
                        obj.mcStatus(2) = 0; 
                        obj.mcStatus(3) = 1; %[0,0,1] CCHI_extension period
                    end
                case 'CCHIext'
                    obj.mcStatus = zeros(1,3);
                case 'SCHI'    
                    obj.mcStatus(1) = 1;
                    obj.mcStatus(2) = 0;
                    
                    
                    if obj.SCHcount > 0
                        obj.SCHcount = obj.SCHcount - 1;     
                        if obj.SCHcount == 0                                                                                                                                       
                            obj.releaseSCH();                                                                                                                     
                        end
                    end
                    
                                       
            end
            [events, obj.multiChannelSwitch] = obj.mcCheck(obj.mcStatus);
        end
        
        
        
    end
    
    methods (Access = private)
        function events = updateChannelStatus(obj,entity)
            coder.extrinsic('num2str');
            events = obj.initEventArray();
            obj.onehopSCHinfo = entity.data.field1;
            twohopSCHinfo = entity.data.field2;
            obj.SCHStatus = zeros(1,6); % update channel status once received WSA
            obj.SCHStatus = (obj.SCHStatus + twohopSCHinfo).*2;
            obj.SCHStatus(obj.onehopSCHinfo) = 1;
            
            disp(['    Vehicle' num2str(obj.vehicleID) '_WME updates SCH info<' num2str(obj.SCHStatus) '>, prepare to join WBSS on SCH ' num2str(obj.onehopSCHinfo)])
            obj.SCHcount = obj.SCHcount + 1;
%             events = obj.eventGenerate(1,'joinWBSS',0,300);
        end
        
        function releaseSCH(obj)
            coder.extrinsic('num2str');
            disp(['T = ' num2str(obj.getCurrentTime() * 1000) 'ms, vehicle' num2str(obj.vehicleID) '_WME releaseSCH. =============' ]);
            if obj.chosenSCH ~= 0
                obj.SCHStatus(obj.chosenSCH) = 0;
                obj.chosenSCH = 0;
            elseif obj.onehopSCHinfo ~=0
                obj.SCHStatus(obj.onehopSCHinfo) = 0;
                obj.onehopSCHinfo = 0;
            end
        end
        
        function events = selectSCH(obj)
            coder.extrinsic('num2str');
            
            if obj.mcStatus(1) == 0 && obj.mcStatus(2) == 1 %if currently SCH
                obj.SCHcount = obj.SCHcount + 2;
            else            
                obj.SCHcount = obj.SCHcount + 1;
            end
            
            if sum(obj.SCHStatus) < 6 % Available SCH exists
                for i = 1:length(obj.SCHStatus)
                    if obj.SCHStatus(i) == 0
                        obj.SCHStatus(i) = 1;
                        obj.chosenSCH = i;
                        break;
                    end
                end
            else
                % If no empty SCH available, pick a random one;
                % More complicated algorithm can be applied here;
                obj.chosenSCH = randi(6);                
            end
                        
            disp(['    Vehicle' num2str(obj.vehicleID) '_WME selects SCH ' num2str(obj.chosenSCH) ' SCHcount ' num2str(obj.SCHcount)]);
            events = obj.eventGenerate(1,'MCinfoReply',0,300);
        end
        
        
        function [events, mcSwitch] = mcCheck(obj, mcStatus)
            coder.extrinsic('num2str');
            mcSwitch = 0;
            events = obj.initEventArray();
            if mcStatus(1) == 1 % GI [1,0,0];                
                mcSwitch = 100;
                events = obj.eventTimer('GI', 4/1000); % Guard interval, 4ms
                disp(['T = ' num2str(obj.getCurrentTime()*1000)  'ms: WME reports GI - mcSwitch ' num2str(mcSwitch) 'SCHCount ' num2str(obj.SCHcount)]);
            end
            
            if mcStatus(1) == 0 && mcStatus(2) == 0 % CCHI [0,0,x]
                mcSwitch = 0;
                if mcStatus(3) == 0
%                     disp('WME reports CCHI');
                    disp(['T = ' num2str(obj.getCurrentTime()*1000)  'ms: WME reports CCHI - mcSwitch ' num2str(mcSwitch) 'SCHCount ' num2str(obj.SCHcount)]);
                    events = obj.eventTimer('CCHI', 46/1000);
                else 
                    disp(['T = ' num2str(obj.getCurrentTime()*1000)  'ms: WME reports CCHIext - mcSwitch' num2str(mcSwitch) 'SCHCount ' num2str(obj.SCHcount)]);
                    events = obj.eventTimer('CCHIext', 50/1000);
                end
            elseif mcStatus(1) == 0 && mcStatus(2) == 1 % SCHI [0,1,x]
                
                if obj.chosenSCH ~= 0
                    mcSwitch = obj.chosenSCH;
                elseif obj.onehopSCHinfo ~= 0
                    mcSwitch = obj.onehopSCHinfo;
                else
                    mcSwitch = 100;
                end
%                 disp(['WME reports SCHI_']);
                disp(['T = ' num2str(obj.getCurrentTime()*1000)  'ms: WME reports <-SCHI-> - mcSwitch ' num2str(mcSwitch) 'SCHCount ' num2str(obj.SCHcount)]);
                events = obj.eventTimer('SCHI', 46/1000);
            end  
            events = [events obj.eventGenerate(1, 'test', 0, 300)];
        end
        
        
    end
    
    methods (Access = protected)
        function num = getNumInputsImpl(~)
            num = 1;
        end
        
        function num = getNumOutputsImpl(~)
            num = 2;
        end
        
        function [sz,dt,cp] = getDiscreteStateSpecificationImpl(~,~)
            sz = [1,1];
            dt = 'double';
            cp = false;
        end
        
        function entityTypes = getEntityTypesImpl(obj)
            entityTypes = obj.entityType('mgmFrame','mgmFrame');
        end
        
        function [inputTypes, outputTypes] = getEntityPortsImpl(obj)
            inputTypes = {'mgmFrame'};
            outputTypes = {'mgmFrame','mgmFrame'};
        end
        
        function [storageSpecs, I, O] = getEntityStorageImpl(obj)
            storageSpecs = obj.queueFIFO('mgmFrame',inf); % to APP layer and SCH(MAC) 1
            I = 1; 
            O = [1,1];
        end
        
        function setupImpl(obj)
            coder.extrinsic('evalin');
            obj.enCCHIext = 0;
            obj.enCCHIext = evalin('base', 'enCCHIext');
        end
    end
    

end
