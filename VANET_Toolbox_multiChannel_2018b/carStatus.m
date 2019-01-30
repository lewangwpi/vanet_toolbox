classdef carStatus < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        carID % car id is stored ned to be a interger
        txPower % power of transmisition in dbm
        awRange % Target Awarness range
        senseThreshold = -85 %  Carrier sense threshold [dBm]
        packetRate = 10 % Packet rate per second 
        awRatio  = 0.85% percentage of awarness of the car
        currentdelta % delta of TA minus eNar
        lastReceivedLinks
        currentRatio
        
        latitude=0;
        longitude=0;
        lane=0;        
        speedX=0;
        speedY=0;
        acceleration=0;
        
    end
    
    methods
        function obj = carStatus(carIDin,txPowerin,rangein)
         
         %% Pre Initialization %%
         % Any code not using output argument (obj)
         if nargin == 0
            % Provide values for superclass constructor
            % and initialize other inputs
                    obj.carID = 999;
                    obj.txPower = 23;
                    obj.awRange = 100;
         
         elseif nargin == 1
                    obj.carID = carIDin;
                    obj.txPower = 23;
                    obj.awRange = 100;
         elseif nargin == 2
                    obj.carID = carIDin;
                    obj.txPower = txPowerin;
                    obj.awRange = 100;
         elseif nargin == 3
                    obj.carID = carIDin;
                    obj.txPower = txPowerin;
                    obj.awRange = rangein; 
         end
        end
        
        
    end
    
end

