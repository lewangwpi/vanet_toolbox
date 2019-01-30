classdef des_MAC_MLMEext < matlab.DiscreteEventSystem
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
        channelStatus = 1; % 1 - SCH; 0 - CCH
    end

    % Discrete-event algorithms
    methods
%         function events = setupEvents(obj)
% %             events = obj.eventGenerate(8,'initTimeInterval',0,300);
%         end
        
        function [entity,events] = entry(obj,storage,entity,source)
            % Specify event actions when entity enters storage           
            events = [];
        end
        
        
        
        
    end
    
    methods (Access = protected)
        function num = getNumInputsImpl(~)
            num = 8;
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
            entityTypes = obj.entityType('mgmFrame','mgmFrame');
        end
        
        function [inputTypes, outputTypes] = getEntityPortsImpl(obj)
            inputTypes = {'mgmFrame','mgmFrame','mgmFrame','mgmFrame','mgmFrame','mgmFrame','mgmFrame','mgmFrame'};
            outputTypes = {'mgmFrame','mgmFrame','mgmFrame','mgmFrame','mgmFrame','mgmFrame','mgmFrame'};
        end
        
        function [storageSpecs, I, O] = getEntityStorageImpl(obj)
            storageSpecs = [obj.queueFIFO('mgmFrame',inf)... % 1 - CH0(CCH) control;
                            obj.queueFIFO('mgmFrame',inf)... % 2 - CH1(SCH1) control;
                            obj.queueFIFO('mgmFrame',inf)... % 3 - CH2(SCH2) control;
                            obj.queueFIFO('mgmFrame',inf)... % 4 - CH3(SCH3) control;
                            obj.queueFIFO('mgmFrame',inf)... % 5 - CH4(SCH4) control;
                            obj.queueFIFO('mgmFrame',inf)... % 6 - CH5(SCH5) control;
                            obj.queueFIFO('mgmFrame',inf)... % 7 - CH6(SCH6) control;
                            obj.queueFIFO('mgmFrame',inf)];  % 8 - MGM msg from APP_WME
            I = [1,2,3,4,5,6,7,8]; 
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
