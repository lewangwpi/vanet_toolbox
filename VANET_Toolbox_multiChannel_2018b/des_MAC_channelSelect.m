classdef des_MAC_channelSelect < matlab.DiscreteEventSystem
    % Pre-computed constants
    properties(Access = private)

    end

    % Discrete-event algorithms
    methods
        function [entity,events] = entry(obj,storage,entity,source)
            % Specify event actions when entity enters storage
            events = obj.initEventArray;
            coder.extrinsic('num2str');

            if storage == 1 
%                 disp(['Vehicle ' num2str(entity.data.Address2) ' -> enters channelSelect']);
                events = obj.eventForward('output',1,0);
            else
%                 disp(['des_MAC_channelSelect :: Receive waveform to other channel *****************' num2str(storage)]);
                events = obj.eventForward('storage',1,0);
            end
                
            
        end
    end
    
    methods (Access = protected)
        function num = getNumInputsImpl(~)
            num = 7;
        end
        
        function num = getNumOutputsImpl(~)
            num = 1;
        end
        
        function [sz,dt,cp] = getDiscreteStateSpecificationImpl(~,~)
            sz = [1,1];
            dt = 'double';
            cp = false;
        end
        
        function entityTypes = getEntityTypesImpl(obj)
            entityTypes = obj.entityType('waveform','Waveform');
        end
        
        function [inputTypes, outputTypes] = getEntityPortsImpl(obj)
            inputTypes = {'waveform','waveform','waveform','waveform','waveform','waveform','waveform'};
            outputTypes = {'waveform'};
        end
        
        function [storageSpecs, I, O] = getEntityStorageImpl(obj)
            storageSpecs = [obj.queueFIFO('waveform',inf)... % 1 - APP_Input; Output_CCH;
                            obj.queueFIFO('waveform',inf)... % 2 - Output_SCH1;
                            obj.queueFIFO('waveform',inf)... % 3 - Output_SCH1;
                            obj.queueFIFO('waveform',inf)... % 4 - Output_SCH1;
                            obj.queueFIFO('waveform',inf)... % 5 - Output_SCH1;
                            obj.queueFIFO('waveform',inf)... % 6 - Output_SCH1;
                            obj.queueFIFO('waveform',inf)];  % 7 - Output_SCH1;
            I = [1,2,3,4,5,6,7]; 
            O = 1;
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
