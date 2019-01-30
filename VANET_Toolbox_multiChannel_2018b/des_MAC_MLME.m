classdef des_MAC_MLME < matlab.DiscreteEventSystem & matlab.system.mixin.Propagates & matlab.system.mixin.SampleTime      
    % Untitled3 Add summary here
    %
    % This template includes the minimum set of functions required
    % to define a Discrete Event System object.

    % Public, tunable properties
    properties
        vehicleID = 0;
    end

    properties(DiscreteState)

    end

    % Pre-computed constants
    properties(Access = private)
        multiChannelStatus = zeros(1,6);
        chosenSCH = 0;
        onehopSCHinfo = 0;
    end

    % Discrete-event algorithms
    methods
        function [entity,events] = entry(obj,storage,entity,source)
            coder.extrinsic('num2str');
            events = obj.initEventArray;
           
            % Specify event actions when entity enters storage    
            disp(['receive channel coordination message from APP data plane']);
            switch entity.data.type
                case 1 % multichannel status update 
                    events = obj.updateChannelStatus(entity);
                case 2 % multichannel status inquiry                     
                    events = obj.selectSCH;                    
                case 3 % multichannel status release message
                    events = obj.releaseSCH(entity);       
                
            end
        end
        
        function [entity,events] = mgmFrameGenerate(obj,storage,entity,tag)
            coder.extrinsic('num2str');
            events = obj.initEventArray;
            switch tag
                case 'MCinfoReply'                    
                    entity.data.type = 4; % type 4, reply to APP data plane about chosen SCH
                    entity.data.field1 = obj.chosenSCH;                    
                    disp(['    Vehicle' num2str(obj.vehicleID)  '_WME replies APP layer --> SCH ' num2str(obj.chosenSCH)]);
                    events = [obj.eventGenerate(1,'createWBSS',0,300), obj.eventForward('output',1,0)];
                case 'createWBSS'
                    
                    entity.data.type = 5; % type 5, mgm msg to MLMEext to coordinate Multi-MAC configuration                    
                    entity.data.field1 = obj.chosenSCH;
                    disp(['    Vehicle' num2str(obj.vehicleID) '_WME creates WBSS on SCH ' num2str(entity.data.field1)]);
                    events = obj.eventForward('output',2,0);  
                case 'joinWBSS'
                    entity.data.type = 5; % type 5, mgm msg to MLMEext to coordinate Multi-MAC configuration         
                    entity.data.field1 = obj.onehopSCHinfo;
                    disp(['    Vehicle' num2str(obj.vehicleID) '_WME sends MAC management frame to MAC' num2str(entity.data.field1)]);
                    events = obj.eventForward('output',2,0);
                case 'resetMCinfo'
                    entity.data.type = 5; % type 5, mgm msg to MLMEext to coordinate Multi-MAC configuration         
                    entity.data.field1 = 0;
                    disp(['    Vehicle' num2str(obj.vehicleID) '_WME sends reset MC info message_' ]);
                    events = obj.eventForward('output',2,0);
            end
        end
    end
    
    methods
        function events = updateChannelStatus(obj,entity)
            coder.extrinsic('num2str');
            obj.onehopSCHinfo = entity.data.field1;
            twohopSCHinfo = entity.data.field2;
            obj.multiChannelStatus = zeros(1,6); % update channel status once received WSA
            obj.multiChannelStatus = (obj.multiChannelStatus + twohopSCHinfo).*2;
            obj.multiChannelStatus(obj.onehopSCHinfo) = 1;
            
            disp(['    Vehicle' num2str(obj.vehicleID) '_WME updates SCH info<' num2str(obj.multiChannelStatus) '>, prepare to join WBSS on SCH ' num2str(obj.onehopSCHinfo)])
            events = obj.eventGenerate(1,'joinWBSS',0,300);
        end
        
        function events = releaseSCH(obj,entity)
            coder.extrinsic('num2str');
            releaseSCHNum = entity.data.field1;
            obj.multiChannelStatus(releaseSCHNum) = 0;
            disp(['T = ' num2str(obj.getCurrentTime()) ' vehicle_' num2str(obj.vehicleID) '_WME reset SCH_' num2str(releaseSCHNum)]);
            events = obj.eventGenerate(1,'resetMCinfo',0,300);
        end
        
        function events = selectSCH(obj)
            coder.extrinsic('num2str');
            for i = 1:length(obj.multiChannelStatus)
                if obj.multiChannelStatus(i) == 0
                    obj.multiChannelStatus(i) = 1;
                    obj.chosenSCH = i;
                    break;
                end
            end
            disp(['    Vehicle' num2str(obj.vehicleID) '_WME selects SCH ' num2str(obj.chosenSCH)]);
            events = obj.eventGenerate(1,'MCinfoReply',0,300);
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
    end

    methods(Access = protected)
        function setupImpl(obj)
            % Perform one-time calculations, such as computing constants
        end

        function resetImpl(obj)
            % Initialize / reset discrete-state properties
        end
    end
end
