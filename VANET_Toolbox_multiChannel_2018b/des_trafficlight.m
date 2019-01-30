classdef des_trafficlight < matlab.DiscreteEventSystem & matlab.system.mixin.SampleTime
    % Untitled Add summary here
    %
    % This template includes the minimum set of functions required
    % to define a Discrete Event System object.

    % Public, tunable properties
    properties
        greenLight=15;
        yellowLight=1.5;
%         redLight=3.5;
    end

    properties(DiscreteState)

    end

    % Pre-computed constants
    properties(Access = private)

    end

    % Discrete-event algorithms
    methods
        function [entity,events] = lightEntry(obj,storage,entity,source)                    
            events=obj.initEventArray;
            events=[events obj.eventTimer('weYELLOW',obj.greenLight), obj.eventTimer('nsGREEN',obj.greenLight+obj.yellowLight)];
        end

        function [entity,events]=lightTimer(obj,storage,entity,tag)
            events=obj.initEventArray;
            coder.extrinsic('num2str');
            coder.extrinsic('plotLight');
            coder.extrinsic('fcn_carGlobalDB');
            tag=tag(tag~=0);
            plotLight(tag);
            fcn_carGlobalDB('setLight',tag);
            switch tag
                case 'weGREEN'                    
                    events=[events obj.eventTimer('weYELLOW',obj.greenLight)];
                case 'weYELLOW'
                    events=[events obj.eventTimer('weRED',obj.yellowLight)];
                case 'weRED'
                    events=[events obj.eventTimer('weGREEN',obj.greenLight+obj.yellowLight)];
                case 'nsGREEN'
                    events=[events obj.eventTimer('nsYELLOW',obj.greenLight)];
                case 'nsYELLOW'
                    events=[events obj.eventTimer('nsRED',obj.yellowLight)];
                case 'nsRED'
                    events=[events obj.eventTimer('nsGREEN',obj.greenLight+obj.yellowLight)];               
            end
        end
        
    end

    methods(Access = protected)
%         function setupImpl(obj)
%         end
        
        function num=getNumInputsImpl(~)
            num=1;
        end
        
        function num=getNumOutputsImpl(~)
            num=1;
        end
        
        function entityTypes=getEntityTypesImpl(obj)
            entityTypes=obj.entityType('light','double');
        end
        
        function [storageSpecs,I,O]=getEntityStorageImpl(obj)
            storageSpecs=obj.queueFIFO('light',inf);                 
            I=1;
            O=1;                        
        end      
        
    end
end
