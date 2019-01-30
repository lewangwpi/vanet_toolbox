classdef des_MAC_macSelect < matlab.DiscreteEventSystem
    % Pre-computed constants
    properties(Access = private)

    end

    % Discrete-event algorithms
    methods
        function [entity,events] = entry(obj,storage,entity,source)
            coder.extrinsic('num2str');
            events = obj.initEventArray;
            switch storage 
                case 7
                    switch entity.data.channelNum
                        case 1
                            events = obj.eventForward('storage',6,0);
                        case 2
                            events = obj.eventForward('storage',5,0);
                        case 3
                            events = obj.eventForward('storage',4,0);
                        case 4
                            events = obj.eventForward('storage',3,0);
                        case 5
                            events = obj.eventForward('storage',2,0);
                        case 6 
                            events = obj.eventForward('storage',1,0);
                        otherwise
                            events = obj.eventForward('output',storage, 0);
%                             disp(['Send to CCH ' num2str(entity.data.channelNum)]);
                            
                    end
                otherwise
                    assert(7-storage == entity.data.channelNum);
                    events = obj.eventForward('output',storage,0);
%                     disp(['Send to SCH ' num2str(7-storage)]);
            end
        end
    end
    
    methods (Access = protected)
        function num = getNumInputsImpl(~)
            num = 1;
        end
        
        function num = getNumOutputsImpl(~)
            num = 7;
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
            inputTypes = {'waveform'};
            outputTypes = {'waveform','waveform','waveform','waveform','waveform','waveform','waveform'};
        end
        
        function [storageSpecs, I, O] = getEntityStorageImpl(obj)
            storageSpecs = [obj.queueFIFO('waveform',inf)... % 1 - APP_Input; Output_CCH;
                            obj.queueFIFO('waveform',inf)... % 2 - Output_SCH1;
                            obj.queueFIFO('waveform',inf)... % 3 - Output_SCH1;
                            obj.queueFIFO('waveform',inf)... % 4 - Output_SCH1;
                            obj.queueFIFO('waveform',inf)... % 5 - Output_SCH1;
                            obj.queueFIFO('waveform',inf)... % 6 - Output_SCH1;
                            obj.queueFIFO('waveform',inf)];  % 7 - Output_SCH1;
            I = 7; 
            O = [1,2,3,4,5,6,7];
        end
    end
end
