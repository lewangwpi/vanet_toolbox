% runModel(simTime,roadtype,minVehicleNum,maxVehicleNum,gap,simRound,errBar,macTXT)
%     1. simTime
%     2. roadType
%     3. minVehicleNum
%     4. maxVehicleNum
%     5. gap
%     6. simRound
%     7. errBar
%     8. macTxt
%     9. appTxt
%     10. mapUI
function fcn_runModel(varargin)   
    disp('Running');
%     profile on;    
%     minNumvehicles=N;
%     maxNumvehicles=minNumvehicles;
    minNumvehicles=varargin{3};
    maxNumvehicles=varargin{4};
    gap=varargin{5};

    simTime=varargin{1};

    maxSimCount=varargin{6};   
    vanet_init();
    vehicle=struct(...
        'PositionX',0,...
        'PositionY',0,...
        'Speed',50,...
        'Acceleration',5,...  % init acceleration
        'VehicleID',1,...
        'lane',1);
        
    vanet=struct(...
        'numVehicles',2,...
        'vehicles',[],...
        'txtEnable',varargin{8},...
        'appTXTEnable',varargin{9},...
        'isUIon',varargin{10});    

        arrayInd=[]; % x axis array for errorplot(x,y,e)
        ind1=1; % column for 2-d array --> runTime
    for j=minNumvehicles:gap:maxNumvehicles               
        if j<2
            j=2;
        end        
        arrayInd=[arrayInd j];
        for simCount=1:maxSimCount
            tic    
            % vanet network with 3 vehicles
            n = vanet;
            n.numVehicles = j;                

            for i=1:maxNumvehicles        
                % % Setup station parameters
                s{i}=vehicle;
                s{i}.PositionX=0;
                s{i}.Speed=50;
                s{i}.Acceleration=10/3.6;
                s{i}.VehicleID=i;        

                n.vehicles=[n.vehicles s{i}];                
            end

            % Simulate the vanet network for a period of time (in ms)
            switch varargin{2} %roadType
%                 case '1lane1drt'
                case '11'
                    fcn_simHighway(n,simTime); % 1 lane, 1 direction
                case '21'        
                    fcn_simHighway(n,simTime,2,1); % 2 lanes, 1 direction
                case '22'
                    fcn_simHighway(n,simTime,2,2); % 2 lanes, 2 directions
                case '42'
                    fcn_simHighway(n,simTime,4,0); % 4 lanes, 2 directions
                case '44'
                    fcn_simIntersection(n,simTime); % crossing with traffic light                    
            end

            runTime(simCount,ind1)=toc;      
        end    
        ind1=ind1+1;
    end    

%     if strcmp(errbar,'on')
    if varargin{7}==1 % if errbar option is on
        figure(3);
        plotErrorbar(runTime,arrayInd);

        FileName=['results/runTime-',datestr(now, 'yyyymmddHHMM'),['-v' num2str(minNumvehicles) '_' num2str(gap) '_' num2str(maxNumvehicles) '-' num2str(maxSimCount) 'by' num2str(simTime) 's' ],'.mat'];
        save(FileName,'runTime');
    
        title('Number of vehicles VS simulation period')
        xlabel('Number of vehicles');
        ylabel('Simulation Time (s)');
    end
% 
%     profile off;
%     profile viewer;
end
