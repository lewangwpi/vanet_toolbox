classdef des_PHY_links < matlab.DiscreteEventSystem & matlab.system.mixin.Propagates & matlab.system.mixin.SampleTime

    properties(Access = private)
        channelDelay
        phyTXTEnable
    end

    methods(Access = protected)
        function entityTypes=getEntityTypesImpl(obj)
            entityTypes=obj.entityType('waveform','Waveform');
        end
        
        function [inputTypes,outputTypes]=getEntityPortsImpl(obj)
            inputTypes='waveform';
            outputTypes='waveform';
        end
        
        function [storageSpecs,I,O]=getEntityStorageImpl(obj)
            storageSpecs=obj.queueFIFO('waveform',inf);
            I=1;
            O=1;                        
        end
        
        function setupImpl(obj)
            coder.extrinsic('fcn_carGlobalDB');            
            coder.extrinsic('fcn_carLocalDB');
            coder.extrinsic('fcn_CAVrecord');
            coder.extrinsic('exist');
            coder.extrinsic('evalin');            
            coder.extrinsic('fcn_eventsCount');
            
            fcn_eventsCount('init');
            fcn_carGlobalDB('init');  
            fcn_carLocalDB('init');
            
            if exist('simTime','var')                                   
                simTime=evalin('base','simTime');    
            else                
                simTime=30;
            end            
            
            obj.phyTXTEnable=0;
            obj.phyTXTEnable=evalin('base','txtEnable');
            
            numVehicles=evalin('base','numStations');    
            fcn_CAVrecord('init',numVehicles,simTime);     
                                    
            waveformlength=1;
            waveformlength=evalin('base','waveformLength');
            obj.channelDelay=waveformlength/10000000;
        end
        
    end
    
    methods
        function [entity,events]=waveformEntry(obj,storage,entity,src)
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('phy');
            coder.extrinsic('phy_ChannelSensing');            
            phy_ChannelSensing(0,1,0);
            entity.data.SNR=100;                        
            if sum(entity.data.ACKBody)==0             % Data, not ACK
                waveformPayloadBuffer=entity.data.Body;   
                phy_ChannelSensing(3,waveformPayloadBuffer,entity.data.Address2,obj.getCurrentTime()*1000,obj.phyTXTEnable);
                events=obj.eventTimer('dataProp',obj.channelDelay); % Data tx time
            else                                       % ACK
                waveformPayloadBuffer=entity.data.ACKBody; 
                phy_ChannelSensing(4,waveformPayloadBuffer,entity.data.Address2,obj.getCurrentTime()*1000,obj.phyTXTEnable);
                events=obj.eventTimer('ackProp',0.0000975); %  ACK time
            end            
        end
        
        function [entity,events]=waveformTimer(obj,storage,entity,tag)     
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('phy');
            coder.extrinsic('phy_ChannelSensing');
            coder.extrinsic('evalin');
            tag=tag(tag~=0);
            switch tag
                case 'dataProp'
                    o=phy_ChannelSensing(5,obj.getCurrentTime(),entity.data.Address2,entity.data.ACTag);
                    entity.data.Body=o;
                case 'ackProp'
                    o=ones(975,1)*(1i);
                    o=phy_ChannelSensing(6,0,entity.data.Address2);
                    entity.data.ACKBody=o;
            end
            events=obj.eventForward('output',1,0);
        end
        
        function events=waveformExit(obj,storage,entity,dst)
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('phy');
            coder.extrinsic('phy_ChannelSensing');
            phy_ChannelSensing(0,0,0);          %reset channel status
            phy_ChannelSensing(2,0,0);          % reset channel waveform buffer
%             disp('<---Channel--->: channel is reset');
            events=[];
        end
    end
    
end
