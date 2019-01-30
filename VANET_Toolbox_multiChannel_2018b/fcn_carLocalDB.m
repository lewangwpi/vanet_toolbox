function varargout=fcn_carLocalDB(varargin)
    
    % varargin{1}: actions
        % actions: init --> ('init',selfID,posX,posY,laneID);
        % actions: set --> ('set',selfID,otherID,posX,posY,laneID)
        % actions: get --> ('get',selfID,otherID)

    persistent localDatabase    
    
    switch varargin{1}
        case 'init'
            localDatabase=containers.Map('KeyType','double', 'ValueType','any');
        case 'clearmem'
            clearvars localDatabase;
            
        case 'set'
            if ~isKey(localDatabase,varargin{2})
                localDatabase(varargin{2})=containers.Map('KeyType','double', 'ValueType','any');                                                                                                 
            end                        
            
            localDB=localDatabase(varargin{2});             
            
            if ~isKey(localDB,varargin{3})
                localDB(varargin{3})=carStatus;                                       
            end
            
            carObj=localDB(varargin{3});                                         
            carObj.carID=varargin{3};                         
            carObj.latitude=varargin{4};                                            
            carObj.longitude=varargin{5};                         
            carObj.lane=varargin{6};    
            carObj.speedX=varargin{7};
            carObj.speedY=varargin{8};
            carObj.acceleration=varargin{9};
            
        case 'get' % 暖et',obj.vehicleID) || ('get',obj.vehicleID,tgPosY);
%             varargout{1}=ones(2,2)*1000;
            if isKey(localDatabase,varargin{2})
                localDB=localDatabase(varargin{2});     
                
                switch nargin
                    case 2
                        longitude=localDB(varargin{2}).longitude;                    
                    case 3
                        longitude=varargin{3};
                end
                
                index=localDB.keys;
%                 index=cellfun(@str2num,localDB.keys);
                tempArray=zeros(localDB.Count,2);                                
                
                j=1;
                for i=1:localDB.Count
                    if localDB(index{i}).longitude==longitude && localDB(index{i}).lane==localDB(varargin{2}).lane                
                        tempValue=localDB(index{i}).latitude-localDB(varargin{2}).latitude;       
                        if tempValue~=0
                            tempArray(j,1)= tempValue;
                            tempArray(j,2)=localDB(index{i}).carID;
                            j=j+1;
                        end
                    end                    
                end
                
                varargout{1}=localDBprocess(tempArray);
                
                %% varargout{2}
                bsmInfo=zeros(2,7);
                
                out=varargout{1};
                if isKey(localDB,out(1,2))
                    frontCarStatus=localDB(out(1,2));
                    bsmInfo(1,1)=frontCarStatus.carID;                
                    bsmInfo(1,2)=frontCarStatus.latitude;                
                    bsmInfo(1,3)=frontCarStatus.longitude;                
                    bsmInfo(1,4)=frontCarStatus.lane;                
                    bsmInfo(1,5)=frontCarStatus.speedX;                
                    bsmInfo(1,6)=frontCarStatus.speedY;                
                    bsmInfo(1,7)=frontCarStatus.acceleration;
                end
                
                if isKey(localDB,out(2,2))
                    backCarStatus=localDB(out(2,2));                                                                    
                    bsmInfo(2,1)=backCarStatus.carID;                
                    bsmInfo(2,2)=backCarStatus.latitude;                
                    bsmInfo(2,3)=backCarStatus.longitude;                
                    bsmInfo(2,4)=backCarStatus.lane;                
                    bsmInfo(2,5)=backCarStatus.speedX;                
                    bsmInfo(2,6)=backCarStatus.speedY;                
                    bsmInfo(2,7)=backCarStatus.acceleration;
                end
                
                varargout{2}=bsmInfo;                                
                
            end
    end
        
end

function out=localDBprocess(inArray) %find distance and carID of front car and back car to the target car 
    [row,col]=size(inArray);
    gt=[]; % greater than
    gti=1; % greater than index
    st=[]; % smaller than
    sti=1; % smaller than index
    out=1000*ones(2,2);
    
    for i=1:row
        if inArray(i,1)>0
            gt(gti,1)=inArray(i,1);
            gt(gti,2)=inArray(i,2);
            gti=gti+1;
        elseif inArray(i,1)<0
            st(sti,1)=inArray(i,1);
            st(sti,2)=inArray(i,2);
            sti=sti+1;   
        end
    end
    
    if ~isempty(gt)
        [gtvalue,gtindex]=min(gt(:,1));
        out(1,1)=abs(gtvalue);
        out(1,2)=gt(gtindex,2);
    end
    
    if ~isempty(st)
        [stvalue,stindex]=max(st(:,1));
        out(2,1)=abs(stvalue);
        out(2,2)=st(stindex,2);
    end    
end
