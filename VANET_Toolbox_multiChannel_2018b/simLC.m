function simLC(varargin) % simLC(numVehicle/speedArray,simTime, laneChangingOption, isappTXTon)        
    simTime=varargin{2};
    assignin('base','simTime',simTime);
    
    if numel(varargin{1})==1       
        numVehicles=max(4,varargin{1});
    else
        numVehicles=numel(varargin{1});
        speedArray=varargin{1};
    end
    assignin('base','numStations',numVehicles);
            
    if nargin>2        
        switch varargin{3}        
            case 'per'            
                laneChangingOption='Performance Lane Changing';                
            case 'con'
                laneChangingOption='Conservative Lane Changing';       
            otherwise
                laneChangingOption='Brake without Lane Changing';
        end   
    else
        laneChangingOption='Brake without Lane Changing';
    end
    
    
    
    if nargin==4
        isUIon=varargin{4};
    else
        isUIon=0;
    end
    
    
    % laneChangingOption='Performance Lane Changing';
    % speedArray=fcn_generateSpeedArray(numVehicles,70,5);
    
    vehicle=struct(...
        'PositionX',0,...
        'PositionY',0,...
        'Speed',50,...
        'Acceleration',10,...
        'VehicleID',1,...
        'lane',1);

    vanet=struct(...
        'vehicles',[],...       
        'txtEnable',0,...
        'appTXTEnable',0);
    n = vanet;
    
    %% Create a model
    h=new_system;
    
    try
        set_param(h,'StopTime',num2str(simTime));
        mdl=get_param(h,'Name');        
        add_block('VANETlib/Control Panel', [mdl '/controlPanel'], ...                            
                    'txtEnable',n.txtEnable,...
                    'appTXTEnable',n.appTXTEnable,...
                    'isUIon',isUIon,...
                    'road','highway',...
                    'roadLength','1680',...
                    'laneChangingOption',laneChangingOption);
        add_block('VANETlib/vanet PHY layer', [mdl '/VANET'], ...     
                    'numStations', num2str(numVehicles));   

        posX=680:-20:0;
        for i=1:numVehicles
            car=vehicle;
            switch i
                case 1
                    car.Speed=80;
                    car.PositionX=740;
                    car.PositionY=0;
                case 2
                    car.Speed=50;
                    car.PositionX=780;
                    car.PositionY=0;
                case 3
                    car.Speed=90;
                    car.PositionX=700;
                    car.PositionY=4;
                case 4
                    car.Speed=60;
                    car.PositionX=800;
                    car.PositionY=4;
                otherwise      
                    if numel(varargin{1})>1
                        car.Speed=speedArray(i);
                    end
                    
                    car.PositionX=posX(i-4);
                    car.PositionY=mod(i,2)*4;
            end
            add_block('VANETlib/Vehicle', [mdl '/Car' num2str(i)], ...                            
                'carID', num2str(i), ...                                       
                'startSpd',num2str(car.Speed),...          
                'startAcc',num2str(car.Acceleration),...
                'initLane',num2str(car.lane),...
                'startPosX',num2str(car.PositionX),...       
                'startPosY',num2str(car.PositionY));

        end
        
        stopfcn=strcat("fcn_stopfcnList(", num2str(numVehicles),',', num2str(simTime),');');                     
        set_param(mdl,'StopFcn',stopfcn);   
        vanet_init();
        sim(mdl);
        close_system(mdl,0);   
        bdclose;
    catch e
        close_system(mdl,0);
        rethrow(e);
    end
end
        