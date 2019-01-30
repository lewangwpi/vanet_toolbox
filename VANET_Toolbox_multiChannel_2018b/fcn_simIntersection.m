function fcn_simIntersection(varargin)
    h = new_system;
    greenLightPeriod=16;
    yellowLightPeriod=4;
    try
        set_param(h, 'StopTime', num2str(varargin{2}));
        mdl = get_param(h, 'Name');
        
        add_block('VANETlib/Control Panel', [mdl '/controlPanel'], ...                        
            'txtEnable',varargin{1}.txtEnable,...
            'appTXTEnable',varargin{1}.appTXTEnable,...
            'isUIon',varargin{1}.isUIon,...
            'laneChangingOption','Conservative Lane Changing',...
            'road','crossRD');
        
        add_block('VANETlib/vanet PHY layer', [mdl '/VANET'], ... 
                'numStations', num2str(varargin{1}.numVehicles));
            
        add_block ('VANETlib/trafficLight', [mdl '/trafficLight'], ...
                    'green', num2str(greenLightPeriod), ...
                    'yellow', num2str(yellowLightPeriod));
        
        for i=1:varargin{1}.numVehicles
            s=varargin{1}.vehicles(i);
            s.Acceleration=10;
            
            if mod(i,8)~=0
                a=mod(i,8);
            else
                a=8;
            end
            
            switch a
                case {1,5}
                    s.lane=1;
                    s.PositionY=a-1;
                case {2,6}
                    s.lane=2;
                    s.PositionY=a+6;
                case {3,7}
                    s.lane=3;
                    s.PositionY=a-3;
                case {4,8}
                    s.lane=4;
                    s.PositionY=a+4;
            end
            
            s.PositionX=15*(varargin{1}.numVehicles-i);            
            add_block('VANETlib/Vehicle', [mdl '/Car' num2str(i)], ...
                'carID', num2str(s.VehicleID), ...               
                'startSpd',num2str(s.Speed),...          
                'startAcc',num2str(s.Acceleration),...
                'initLane',num2str(s.lane),...
                'startPosX',num2str(s.PositionX),...       
                'startPosY',num2str(s.PositionY));
            
        end
        
        stopfcn=strcat("fcn_carGlobalDB('save',", "'", [num2str(varargin{1}.numVehicles),' Cars in Crossing'], "'",');');
        set_param(mdl,'StopFcn',stopfcn);  
        
        sim(mdl);
        close_system(mdl,0);
    catch e
        close_system(mdl,0);
        rethrow(e);
    end
end
