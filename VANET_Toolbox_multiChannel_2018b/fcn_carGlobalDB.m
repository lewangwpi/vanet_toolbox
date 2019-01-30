function out=fcn_carGlobalDB(varargin)       
    persistent globalDatabase
    persistent sndcnt rcvcnt  pktcolcnt delay accidentcnt crcerrcnt
    persistent lightSignal
    % nargin==0: RESET
    % nargin==1: Check GlobalDatabase
    % nargin==2: fetch the data
    % nargin==3: register info to GLOBALDATABASE 
        % varargin{1}: vehicle ID
        % varargin{2}: positionX info
        % varargin{3}: positionY info
    
    switch varargin{1}
        case 'setLight'
            % 0-> green; 1-> yellow; 2->red;
            switch varargin{2}
                case 'weGREEN'
                    lightSignal(1)=0;
                case 'weYELLOW'
                    lightSignal(1)=1;
                case 'weRED'
                    lightSignal(1)=2;
                case 'nsGREEN'
                    lightSignal(2)=0;
                case 'nsYELLOW'
                    lightSignal(2)=1;
                case 'nsRED'
                    lightSignal(2)=2;
            end            
        case 'getLight'
            
            out=lightSignal;            
        case 'init'
           
            globalDatabase=containers.Map('KeyType','double', 'ValueType','any');            
            sndcnt=zeros(1,4);
            rcvcnt=zeros(1,4);
            pktcolcnt=zeros(1,4);
            crcerrcnt=zeros(1,4);
            accidentcnt=[];
            lightSignal=[0 2]; % lightSignal(we,ns) % 0->green, 1->yellow,2->red
        case 'sent'
            switch varargin{2}
                case 0
                    sndcnt(1)=sndcnt(1)+1;
                case 1
                    sndcnt(2)=sndcnt(2)+1;
                case 2
                    sndcnt(3)=sndcnt(3)+1;
                case 3
                    sndcnt(4)=sndcnt(4)+1;
            end
        case 'latency'
            switch varargin{2}
                case 0
                    rcvcnt(1)=rcvcnt(1)+1;
                    delay(rcvcnt(1),1)=varargin{3};
                case 1
                    rcvcnt(2)=rcvcnt(2)+1;
                    delay(rcvcnt(2),2)=varargin{3};
                case 2
                    rcvcnt(3)=rcvcnt(3)+1;
                    delay(rcvcnt(3),3)=varargin{3};
                case 3
                    rcvcnt(4)=rcvcnt(4)+1;
                    delay(rcvcnt(4),4)=varargin{3};
            end
        case 'collision'
            switch varargin{2}
                case 0
                    pktcolcnt(1)=pktcolcnt(1)+1;
                case 1
                    pktcolcnt(2)=pktcolcnt(2)+1;
                case 2
                    pktcolcnt(3)=pktcolcnt(3)+1;
                case 3
                    pktcolcnt(4)=pktcolcnt(4)+1;
            end
        case 'CRCerror'
            switch varargin{2}            
                case 0                
                    crcerrcnt(1)=crcerrcnt(1)+1;                                    
                case 1                
                    crcerrcnt(2)=crcerrcnt(2)+1;                    
                case 2                
                    crcerrcnt(3)=crcerrcnt(3)+1;                    
                case 3                
                    crcerrcnt(4)=crcerrcnt(4)+1;
            end
        case 'accident'
%             accidentcnt=accidentcnt+1;
            accidentcnt=[accidentcnt varargin{2}];
        case 'save'
%             FileName=['results/statistic-',datestr(now, 'dd-mmm-yyyy-HH-MM-SS'),'.',varargin{2},'.mat'];
            FileName=['results/statistic-',datestr(now, 'yyyymmddHHMM'),'-',varargin{2},'.mat'];
            save(FileName,'delay','pktcolcnt','rcvcnt','sndcnt','accidentcnt','crcerrcnt');     
        case 'clearmem'                             
            clearvars globalDatabase sndcnt rcvcnt  pktcolcnt delay accidentcnt crcerrcnt lightSignal            
        %%
        otherwise
            if nargin==1 % query when accident happened
                out=ones(1,2)*1000;
                index=globalDatabase.keys;
                tempArray=zeros(1,globalDatabase.Count);
                inputCarStatus = globalDatabase(varargin{1});
                for i=1:globalDatabase.Count
                    currentCarStatus = globalDatabase(index{i});
                    
                    if currentCarStatus.longitude==inputCarStatus.longitude && currentCarStatus.lane==inputCarStatus.lane                
                        tempArray(i)=currentCarStatus.latitude-inputCarStatus.latitude;       
                    end
                end
                % tempArray
                if ~isempty(min(tempArray(tempArray>0)))
                    out(1)=abs(min(tempArray(tempArray>0)));
                end

                if ~isempty(max(tempArray(tempArray<0)))
                    out(2)=abs(max(tempArray(tempArray<0)));
                end       
        
            elseif nargin==2 % query if re-enter the road % carGlobalDB(I h,roadLength)
                
                numVehicles=evalin('base','numStations');                
                index=globalDatabase.keys;        
                tempArray=zeros(1,globalDatabase.Count);                
                tempIndArray=[];
                for i=1:globalDatabase.Count                                         
                    tempArray(i)=globalDatabase(index{i}).latitude;                                   
                end            
                for j=1:globalDatabase.Count
                    if globalDatabase(index{j}).latitude>varargin{2}
                        tempIndArray=[tempIndArray index{j}];
                    end
                end
                
                % if all cars are registered in the global database, and
                % if the last car is 20 meters away from the beginning
                % position, and
                % If the inqury car is next one to enter the road 
                
                
                
                if isKey(globalDatabase,numVehicles)==1 && min(tempArray(tempArray>0))>20 && varargin{1}==min(tempIndArray)
                    out=double(1);            
                else
                    out=double(0);            
                end            
            elseif nargin==4 % set global database
                globalDatabase(varargin{1})=carStatus;
                carObj=globalDatabase(varargin{1});
                carObj.carID=varargin{1};
                carObj.latitude=varargin{2};                   
                carObj.longitude=varargin{3};
                carObj.lane=varargin{4};
            end                                    
    end                                         
end