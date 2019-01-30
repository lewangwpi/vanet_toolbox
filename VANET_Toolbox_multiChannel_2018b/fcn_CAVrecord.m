function varargout=fcn_CAVrecord(varargin)  % varargout=fcn_CAVrecord(action,carID,carSpeed)
    persistent speed avgSpeed avgSpeedAll timeLog avgTimeLog LCLatency LCFailLog
    persistent counter
    
    switch varargin{1}
        case 'init'  % fcn_CAVrecord('init',numVehicles,simTime)
            if nargin~=3
                speed=zeros(3,50); % 3: speed, counter, average speed; 50: save 50 cars' data
                avgSpeed=zeros(50,1000); % 50: save 50 cars' data; 1000 average speed data/car
                avgSpeedAll=zeros(1,1000);
                avgTimeLog=zeros(1,1000);
                timeLog=zeros(50,1000);
                counter=1;
                LCLatency=zeros(50,10);
                LCFailLog=zeros(50,2);
            else
                speed=zeros(3,varargin{2}); % 3: speed, counter, average speed; 50: save 50 cars' data
                avgSpeed=zeros(varargin{2},varargin{3}*11); % 50: save 50 cars' data; 1000000 average speed data/car
                timeLog=zeros(varargin{2},varargin{3}*11);
                avgSpeedAll=zeros(1,varargin{3}*11);
                avgTimeLog=zeros(1,varargin{3}*11);                
                counter=1;
                LCLatency=zeros(varargin{2},10);
                LCFailLog=zeros(varargin{2},2);
            end
        case 'save'  % fcn_CAVrecord('save',carID,speed);         
            speed(1,varargin{2})=speed(1,varargin{2})+varargin{3}; % sum of speed
            speed(2,varargin{2})=speed(2,varargin{2})+1;           % counter
            speed(3,varargin{2})=speed(1,varargin{2})/speed(2,varargin{2});  % average of speed                             
            avgSpeed(varargin{2},speed(2,varargin{2}))=speed(3,varargin{2});            
            timeLog(varargin{2},speed(2,varargin{2}))=varargin{4};  % varargin{4}: time            
            avgSp=speed(3,:);
            avgSp=avgSp(avgSp~=0);                        
            numVehicles=numel(avgSp);            
            if mod(counter,numVehicles)==0
                avgSpeedAll(counter/numVehicles)=mean(avgSp);   
                avgTimeLog(counter/numVehicles)=max(timeLog(numVehicles,:));
            end
            counter=counter+1;
        case 'get'
            varargout{1}=speed(3,varargin{2});
        
        
        case 'logLCLatency' % fcn_CAVrecord('logLCLatency',obj.vehicleID,LCLatency);
            LCLatency=fcn_array2database(LCLatency,varargin{2},varargin{3});
            
        case 'logLCTimeoutNum'
            LCFailLog=fcn_array2database(LCFailLog,varargin{2});
            
        case 'log'            % fcn_CAVrecord('log',numVehiclies)
            avgSpeedAll=avgSpeedAll(avgSpeedAll~=0);            
            m=mean(avgSpeedAll);
            avgSpeedAll(length(avgSpeedAll)+1)=m;            
            time=timeLog(4,:);
            time=time(time~=0);                        
            brakeMode=evalin('base','brakeMode');  
            
            FileName=['results/avgSpeedALL-',brakeMode,'-',varargin{2},'-',datestr(now, 'yyyymmddHHMMSS'),'-.mat'];                         
            save(FileName,'avgSpeedAll','time','LCLatency','LCFailLog');  
            clearvars speed avgSpeed avgSpeedAll timeLog avgTimeLog LCLatency LCFailLog counter;
            
        case 'plot'           % fcn_CAVrecord('plot',numVehicles); 
            figure(5);
            for i=1:varargin{2}
                avgsp=avgSpeed(i,:);
                avgsp=avgsp(avgsp~=0);   
                time=timeLog(i,:);
                time=time(time~=0);               
                h(i)=plot(time,avgsp);    
                hold on;                                                                
            end
            legend(h,'car1','car2','car3','car4','Location','Southeast');   
            xlabel('Simulation time (second)');
            ylabel('Average speed for each car');
            
            
            figure(6)
            avgSpeedAll=avgSpeedAll(avgSpeedAll~=0); 
            plot(time,avgSpeedAll);
            xlabel('Simulation time (second)');
            ylabel('Average overall speed');

            
    end
    
end