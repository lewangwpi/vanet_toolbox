function fcn_simHighway(varargin)
    h = new_system;
    
    try    
        set_param(h, 'StopTime', num2str(varargin{2}));
        mdl = get_param(h, 'Name');
        
        add_block('VANETlib/Control Panel', [mdl '/controlPanel'], ...                        
            'txtEnable',varargin{1}.txtEnable,...
            'appTXTEnable',varargin{1}.appTXTEnable,...
            'isUIon',varargin{1}.isUIon,...
            'road','highway',...
            'laneChangingOption','Brake without Lane Changing');
        
        add_block('VANETlib/vanet PHY layer', [mdl '/VANET'], ... 
                'numStations', num2str(varargin{1}.numVehicles));            
        
        for i = 1:varargin{1}.numVehicles                
            s = varargin{1}.vehicles(i);                                                                
            s.Acceleration=10;                        
            
            if nargin==4 % 4 inputs: network, stopTime, lane#, direction                                
                
                % 4 lanes                
                if varargin{3}>2 % lane#>2, 2 directions automatically, ignore the 4th inputs                                                        
                    if mod(i,4)~=0                                            
                        a=mod(i,4);                                                    
                    else                        
                        a=4;                        
                    end                                        
                    
                    switch a                    
                        case 1                        
                            s.lane=1;                                                            
                        case 2                                                        
                            s.lane=1;                                                            
                        case 3                                                        
                            s.lane=2;                                                           
                        case 4                                                        
                            s.lane=2;                                
                    end                                                            
                    
                    s.PositionX=12.5*(varargin{1}.numVehicles-i);                    
                    s.PositionY=4*(a-1);                    
                    s.Acceleration=abs((s.lane-2)*(mod(s.PositionY,70)+5)+(s.lane-1)*(25-mod(s.PositionY,70)));                                        
                    
                % 2 lanes                        
                elseif varargin{3}==2 
                
                    % 2 lanes, 2 directions                                                         
                    if varargin{4}==2                    
                        s.lane=mod(i,2)+1; % even i to lane 1, odd i to lane 2                                                    
                        s.PositionX=25*(varargin{1}.numVehicles-i);                        
                        s.PositionY=4 * (mod(i,2)+1);
                        
                    % 2 lanes, 1 directions                        
                    else                        
                        s.PositionY=4*mod(i,2); % odd carID to high speed, even carID to low speed                        
                        s.PositionX=25*(varargin{1}.numVehicles-i);                        
                    end                                             
                end
            else % 1 lane, 1 direction                                                   
                s.PositionX=15*(varargin{1}.numVehicles-i);                
            end
                            
            add_block('VANETlib/Vehicle', [mdl '/Car' num2str(i)], ...
                'carID', num2str(s.VehicleID), ...                
                'startSpd',num2str(s.Speed),...          
                'startAcc',num2str(s.Acceleration),...
                'initLane',num2str(s.lane),...
                'startPosX',num2str(s.PositionX),...       
                'startPosY',num2str(s.PositionY));
        end
        
        
        %% StopFcn test
        if nargin==4 % 4 inputs: network, stopTime, lane#, direction                                                              
            % 4 lanes                            
            if varargin{3}>2 % lane#>2, 2 directions automatically, ignore the 4th inputs                                                                    
                stopfcn=strcat("fcn_carGlobalDB('save',", "'", [num2str(varargin{1}.numVehicles), ' Cars'], '-4lanes2directions', "'",');');                
                set_param(mdl,'StopFcn',stopfcn);                                                                                   
            % 2 lanes                                        
            elseif varargin{3}==2                                             
                % 2 lanes, 2 directions                                                                         
                if varargin{4}==2                                    
                    stopfcn=strcat("fcn_carGlobalDB('save',", "'", [num2str(varargin{1}.numVehicles), ' Cars'], '-2lanes2directions',"'",');');                    
                    set_param(mdl,'StopFcn',stopfcn);                                                              
                % 2 lanes, 1 directions                                            
                else                    
                    stopfcn=strcat("fcn_carGlobalDB('save',", "'", [num2str(varargin{1}.numVehicles), ' Cars'],'-2lanes1direction', "'",');');                    
                    set_param(mdl,'StopFcn',stopfcn);                      
                end                                                            
            end                        
                        % 1 lane                
        else                
            stopfcn=strcat("fcn_carGlobalDB('save',", "'", [num2str(varargin{1}.numVehicles), ' Cars'],'-1lane1direction' ,"'",');');                
            set_param(mdl,'StopFcn',stopfcn);      
        end        
        
        sim(mdl);
        close_system(mdl,0);
    
    catch e
        close_system(mdl,0);
        rethrow(e);
    end
end

