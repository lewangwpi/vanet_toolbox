function demoLC(varargin)  % demoLC(numVehicle,simTime,laneChangingOption,isappTXTon);
    if numel(varargin{1})==1
        numVehicles=varargin{1};    
    else
        numVehicles=numel(varargin{1});    
    end
    
%     numVehicles=varargin{1};
    numVehicles=max(4,numVehicles);
    
    simTime=varargin{2};
    isUIon=0;
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
    
    disp(laneChangingOption);
    
    if nargin==4
        isUIon=varargin{4};
    end
    
    %%
    vanet_init();


    vehicle=struct(...        
        'PositionX',0,...
        'PositionY',0,...
        'Speed',50,...
        'Acceleration',10,...  % init acceleration
        'VehicleID',1,...
        'lane',1);

    vanet=struct(...                   
        'vehicles',[],...           
        'linkConfig','Auto',...    
        'txtEnable',0,...       
        'appTXTEnable',1);    

    n = vanet;               
  
    for i=1:numVehicles                         
        s{i}=vehicle;      
        s{i}.VehicleID=i;           
        n.vehicles=[n.vehicles s{i}];                   
    end

    h = new_system;

    try
        set_param(h, 'StopTime', num2str(simTime));

        mdl = get_param(h, 'Name');

        add_block('VANETlib/Control Panel', [mdl '/controlPanel'], ...                            
            'txtEnable',n.txtEnable,...
            'appTXTEnable',n.appTXTEnable,...
            'isUIon',isUIon,...
            'road','highway',...
            'roadLength','1680',...
            'laneChangingOption',laneChangingOption);

        add_block('VANETlib/vanet PHY layer', [mdl '/VANET'], ...     
            'numStations', num2str(numVehicles));    
        
        %%
        car1=n.vehicles(1);    
        car1.Speed=80;
%         car1.Acceleration=10;
        car1.lane=1;
        car1.PositionX=260;
        car1.PositionY=0;

        car2=n.vehicles(2);    
        car2.Speed=50;
        car2.lane=1;
        car2.PositionX=300;
        car2.PositionY=0;

        car3=n.vehicles(3);    
        car3.Speed=90;
        car3.lane=1;
        car3.PositionX=200;
        car3.PositionY=4;

        car4=n.vehicles(4);    
        car4.Speed=60;
        car4.lane=1;
        car4.PositionX=320;
        car4.PositionY=4;                

        carSet=[car1,car2,car3,car4];
        
        %%                        
        if numVehicles>4                           

            zone1 = min(car1.PositionX,car2.PositionX)-80:-30:1;
            zone2 = min(car3.PositionX,car4.PositionX)-80:-30:1;    
            
            zone3 = max(car2.PositionX,car1.PositionX)+40:30:780;           
            zone4 = max(car3.PositionX,car4.PositionX)+60:30:780;
        
            zones={zone1,zone2,zone3,zone4};                        
            
            for j=5:numVehicles
                counter=mod(j,4);
                if counter==0
                    counter=4;
                end
                zone=zones{counter};
                                
                if ~isempty(zone)
                    cars=n.vehicles(j);                                                   
                    cars.PositionX=zone(1);                    
                    if counter==1 || counter==3                    
                        cars.lane=car1.lane;                                                    
                        cars.PositionY=car1.PositionY;                                                 
                    else                        
                        cars.lane=car3.lane;                        
                        cars.PositionY=car3.PositionY;                                                 
                    end
                    
                    if numel(varargin{1})>1
                        speedArray=varargin{1};
                        cars.Speed=speedArray(j);
                    end
                    
%                     cars.Speed=speedArray(j);                    
                    
                    zone=zone(zone~=zone(1));
                    zones{counter}=zone;
                    
                    carSet=[carSet cars];
                elseif counter<4                    
                    counter=counter+1;
                    zone=zones{counter};
                    
                    cars=n.vehicles(j);                                                   
                    cars.PositionX=zone(1);                    
                    if counter==1 || counter==3                    
                        cars.lane=car1.lane;                                                    
                        cars.PositionY=car1.PositionY;                                                 
                    else                        
                        cars.lane=car3.lane;                        
                        cars.PositionY=car3.PositionY;                                                 
                    end              
                    
                    if numel(varargin{1})>1
                        speedArray=varargin{1};
                        cars.Speed=speedArray(j);
                    end
                    
%                     cars.Speed=speedArray(j);
                                        
                    zone=zone(zone~=zone(1));                    
                    zones{counter}=zone;
                    
                    carSet=[carSet cars];
                else % empty(zone) && counter>=4
                    disp('ERROR: Number of vehicles out of road space !!!');
                    break;
                end                                                                                                                                        
            end
        end
            

        for i=1:length(carSet)
            s=carSet(i);            
            add_block('VANETlib/Vehicle', [mdl '/Car' num2str(i)], ...    
                'carID', num2str(s.VehicleID), ...                
                'startSpd',num2str(s.Speed),...          
                'startAcc',num2str(s.Acceleration),...
                'initLane',num2str(s.lane),...
                'startPosX',num2str(s.PositionX),...       
                'startPosY',num2str(s.PositionY));
        end

        stopfcn=strcat("fcn_stopfcnList(", num2str(numVehicles),');');             
        
        set_param(mdl,'StopFcn',stopfcn);   
        
        sim(mdl);
        close_system(mdl,0);



    catch e        
        close_system(mdl,0);    
        rethrow(e);
    end

end



















