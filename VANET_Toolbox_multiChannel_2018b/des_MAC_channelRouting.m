classdef des_MAC_channelRouting < matlab.DiscreteEventSystem
    % Untitled3 Add summary here
    %
    % This template includes the minimum set of functions required
    % to define a Discrete Event System object.

    % Public, tunable properties
    properties

    end

    properties(DiscreteState)

    end

    % Pre-computed constants
    properties(Access = private)

    end

    % Discrete-event algorithms
    methods
        function [entity,events] = payloadEntry(obj,storage,entity,source)
            % Specify event actions when entity enters storage
            coder.extrinsic('num2str');
            events = obj.initEventArray;
            
            switch storage
                case 1
                    switch entity.data.channelNum   
                        case 1
                            events=[events obj.eventForward('storage',2,0)];
                        case 2
                            events=[events obj.eventForward('storage',3,0)];
                        case 3
                            events=[events obj.eventForward('storage',4,0)];
                        case 4
                            events=[events obj.eventForward('storage',5,0)];
                        case 5 
                            events=[events obj.eventForward('storage',6,0)];
                        case 6
                            events=[events obj.eventForward('storage',7,0)];
                        otherwise
                            events=[events obj.eventForward('output',1,0)];
                    end
                case 2
                    events =[events obj.eventForward('output',2,0)];
                case 3
                    events =[events obj.eventForward('output',3,0)];
                case 4
                    events =[events obj.eventForward('output',4,0)];
                case 5
                    events =[events obj.eventForward('output',5,0)];
                case 6
                    events =[events obj.eventForward('output',6,0)];
                case 7
                    events =[events obj.eventForward('output',7,0)];
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
            entityTypes = obj.entityType('payload','Payload');
        end
        
        function [inputTypes, outputTypes] = getEntityPortsImpl(obj)
            inputTypes = {'payload'};
            outputTypes = {'payload','payload','payload','payload','payload','payload','payload'};
        end
        
        function [storageSpecs, I, O] = getEntityStorageImpl(obj)
            storageSpecs = [obj.queueFIFO('payload',inf)... % 1 - APP_Input; Output_CCH;
                            obj.queueFIFO('payload',inf)... % 2 - Output_SCH1;
                            obj.queueFIFO('payload',inf)... % 3 - Output_SCH1;
                            obj.queueFIFO('payload',inf)... % 4 - Output_SCH1;
                            obj.queueFIFO('payload',inf)... % 5 - Output_SCH1;
                            obj.queueFIFO('payload',inf)... % 6 - Output_SCH1;
                            obj.queueFIFO('payload',inf)];  % 7 - Output_SCH1;
            I = 1; 
            O = [1,2,3,4,5,6,7];
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
