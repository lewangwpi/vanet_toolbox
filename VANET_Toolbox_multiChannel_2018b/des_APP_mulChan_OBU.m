classdef des_APP_mulChan_OBU < matlab.DiscreteEventSystem & matlab.system.mixin.Propagates & matlab.system.mixin.SampleTime  
    %% properties
    properties
        vehicleID=1;        % Vehicle ID:
        initVelocity=10; % Start Speed (Km/h):
        initAcc=10; % Seconds 0-100 Km/h:         
        initLane=1; % Initial Lane (1-4):       
        startPositionX=10; % Initial PositionX:
        startPositionY=0;  % Initial PositionY:
        svcRole = 0; % Service Role (Provider/User):
        
        
    end

    % Pre-computed constants
    properties(Access = private)
        entityCounter % the 1st entity is to trigger the movement of the car        
        startTime   % moment when the car enters the road
        curPositionX; % current position
        curPositionY;
        curSpeedX %current speed
        curSpeedY
        carAccidentProcessingPeriod=5; 
        carAccidentTag=0;
        
        distance=1000;
        slowdownTag=0; % 0 - not brake; 1 - start brake delay; 2 - braking
%         laneChangingTag=0;
        decelerationTag=0;
        accidentTag=0;
        startDrivingTag=0;
        
        
        reactDelay=0.67;
        frontCarID=0;
        EMGcounter=0; %when EMGcounter reach to 10, send EMG BSMs for static friction brake
        mapborder=840;
        tgPosY=0;
        speedLimit=120;
        
        roadType='crossRD';
        brakeMode='ConLaneChange';
        emgBrakeMode='PerLaneChange';                
        appTXTEnable=0;
        isUIon=0;
        
        fractionCoe=0.8;
        RDTaddressBook=zeros(1,2);
        dstAddress=0;
        laneChangingAns=0;        
%         performanceLaneChangingSwitch=1;
        
        localDBdist=zeros(2,2);
        localDBinfo=zeros(2,7);
        
        carStatus=0; % 0, carFollowing; 1, laneChanging; 2, at intersection 4, accidient
        reactPeriodTag=0;       
%         oomTag=0; % out of map tag
        LCtimeTag=0;
        lane=1;
        acceleration=0;
        
        spSCHInfo=0; % service provider SCH number
        suSCHInfo=0; % service user SCH number 
        svcInfo = 0; % service info
    end

    
    %% protected methods
    methods(Access = protected)                
        function setupImpl(obj)
            coder.extrinsic('plotMAP');            
            coder.extrinsic('evalin');
            coder.extrinsic('fcn_initInfo');
            
            obj.roadType='crossRD';
            obj.roadType=evalin('base','road');                        
%                                     
%             if strcmp(obj.roadType,'crossRD')
%                 obj.mapborder=200;
%                 obj.mapborder=evalin('base','roadLength');
%                 obj.speedLimit=60;
%             else 
%                 obj.mapborder=840;
%                 obj.mapborder=evalin('base','roadLength');
%                 obj.speedLimit=120;
%             end
            
            obj.mapborder=200;
            obj.mapborder=evalin('base','roadLength');
            
            obj.speedLimit=60;
            obj.speedLimit=evalin('base','speedLimit');
            
            obj.brakeMode='ConLaneChange';
            obj.brakeMode=evalin('base','brakeMode');        
            
            obj.appTXTEnable=0;
            obj.appTXTEnable=evalin('base','appTXTEnable');
                            
            obj.isUIon=0;
            obj.isUIon=evalin('base','isUIon');
            
            if obj.isUIon
                plotMAP(obj.roadType);
            end
                                                                
            obj.lane=obj.initLane;            
            obj.acceleration= 100/(3.6*obj.initAcc);
            obj.curSpeedX=obj.initVelocity;
            obj.curSpeedY=0;
            obj.curPositionX=obj.startPositionX;
            obj.curPositionY=obj.startPositionY;                                                           
        end
        
         function num = getNumInputsImpl(~)
            num = 2;
        end
        
        function num = getNumOutputsImpl(~)
            num = 2;
        end
        
        function [sz,dt,cp] = getDiscreteStateSpecificationImpl(~,~)
            sz = [1,1];
            dt = 'double';
            cp = false;
        end
        
        function entityTypes=getEntityTypesImpl(obj)
            entityTypes=[obj.entityType('payload','Payload')...
                         obj.entityType('mgmFrame','mgmFrame')];
        end
        
        function [inputTypes,outputTypes]=getEntityPortsImpl(~)
            inputTypes={'payload','mgmFrame'};
            outputTypes={'payload','mgmFrame'};
        end
        
        function [storageSpecs,I,O]=getEntityStorageImpl(obj)
            storageSpecs=[obj.queueFIFO('payload',inf)...   % Storage 1: receive entity from upper layer
                          obj.queueFIFO('payload',inf)...   % Storage 2: receive entity from down layer
                          obj.queueFIFO('payload',inf)...   % Storage 3: send to down layer buffer                      
                          obj.queueFIFO('payload',inf)...   % Storage 4: generate new posX buffer
                          obj.queueFIFO('mgmFrame',inf)];   % Storage 5: channel coordination message 
            I=[2,5];
            O=[3,5];                        
        end                       
    end
     
    methods
        function events=setupEvents(obj)       
            coder.extrinsic('fcn_initInfo');
            coder.extrinsic('tic');
            events=obj.initEventArray;
            tic;
            fcn_initInfo('set',obj.vehicleID,obj.curPositionX,obj.curPositionY,obj.lane,obj.curSpeedX,obj.curSpeedY,obj.acceleration);
            %% Test multi-channel test purpose
            if obj.vehicleID == 0
                events = obj.sendMCmsg('test');                
            end
            %%
            events=[events obj.eventGenerate(1,'startDriving',(obj.vehicleID-1)*0.01+0.000001*obj.vehicleID,300) obj.eventGenerate(1,'BSMgen',0.000001*obj.vehicleID,100)];                                    
        end
        
        function [entity,events] = mgmFrameGenerate(obj,storage,entity,tag)
            coder.extrinsic('num2str');
            coder.extrinsic('num2str');
            events = obj.initEventArray;
            entity.data.type = 0;
            entity.data.field1 = 0;
            entity.data.field2 = zeros(1,6);
            switch tag
                case 'requestMCinfo'
                    disp(['T = ' num2str(obj.getCurrentTime()*1000) 'ms, Vehicle' num2str(obj.vehicleID)  '_APP requests multichannel information from WME' ]);
                    entity.data.type = 2;
                case 'rcvWSA'
                    channelStatus = zeros(1,6);
%                     channelStatus(2) = obj.suSCHInfo;
                    
                    entity.data.type = 1; % 1 - update channel status after receiving WSA; 2 - request channel status
                    entity.data.field1 = obj.suSCHInfo; % 1-hop channel status? obtained directly from received WSA
                    entity.data.field2 = channelStatus; % 2-hop channel status, a [1 x 6] vector
                    
                    disp(['    Vehicle' num2str(obj.vehicleID) '_APP generates MGM to WME, 1-hop <' num2str(entity.data.field1) '> 2-hop <' num2str(entity.data.field2) '>']);
                case 'resetMCinfo'
%                     disp('checkcheckcheck');
                    entity.data.type = 3; % 3 - tell management plane two reset multichannel status when the SCH is release due to the complete of service
                    entity.data.field1 = obj.spSCHInfo; % suppose SCH 5 is cleared.
                    obj.spSCHInfo=0; % service provider SCH number
                    obj.suSCHInfo=0; % service user SCH number 
                    obj.svcInfo = 0; % service info
            end
            events = [events obj.eventForward('output',2,0)];
        end
        
        function [entity,events] = mgmFrameEntry(obj,storage,entity,source)
            coder.extrinsic('num2str');
            events = obj.initEventArray;            
            obj.spSCHInfo = entity.data.field1;
            disp(['    Vehicle' num2str(obj.vehicleID) '_APP obtains available SCH ' num2str(obj.spSCHInfo) ' from WME, generating WSA']);
            events = [events obj.eventGenerate(1,'WSAgen',0,100)];            
        end
                
        function [entity,events]=payloadGenerate(obj,~,entity,tag)
            coder.extrinsic('evalin');
            coder.extrinsic('num2str');
            coder.extrinsic('fcn_carGlobalDB');
            coder.extrinsic('fcn_carLocalDB');
%             coder.extrinsic('plotCAV');
            coder.extrinsic('assignin');
            coder.extrinsic('fcn_initInfo');            
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('app');            
            events=obj.initEventArray;                        
            
            [x,y]=fcn_addrConv(obj.curPositionX,obj.curPositionY,obj.lane,obj.mapborder);                    
            entity.data.pos(1)=x;
            entity.data.pos(2)=y;
            
            tag=tag(tag~=0);
            switch tag
                case 'testMultiChannel'
                    payloadlength=evalin('base','payloadLength');
                    entity.data.wsmp=ones(1,payloadlength);
                    entity.data.wsmp=app_msg2wsmp(55,entity.data.wsmp,1);
                    
                    entity.data.VehicleID=obj.vehicleID;
                    entity.data.priority=5;                    
                    entity.data.dstAddress=0;                    
                    entity.data.channelNum=obj.spSCHInfo;
                    
                    disp(['T= ' num2str(obj.getCurrentTime()) ' Vehicle ' num2str(obj.vehicleID) ' generates multi-channel test messge to SCH ' num2str(entity.data.channelNum)]);
                    events =[events obj.eventForward('storage',3,0)];
                case 'WSAgen'
                    payloadlength=evalin('base','payloadLength');
                    entity.data.wsmp=ones(1,payloadlength);
                    % Has to evalin every time when generating entities due
                    % to the code generation. Using a property to initiate
                    % payloadLength will fail the code generation, because
                    % when code generation goes through the code,
                    % setupImpl() method is not triggered, then
                    % obj.payloadLength cannot be evalin from workspace,
                    % then entity.data.wsmp will fail codegen as
                    % payloadLength is not defined.s
                    entity.data.VehicleID=obj.vehicleID;
                    entity.data.priority = 6;
                    entity.data.dstAddress=0;
                    entity.data.channelNum=0;
                    
                    entity.data.wsmp=app_msg2wsmp(222,entity.data.wsmp,1); % field1: WSA type, 222
                    entity.data.wsmp=app_msg2wsmp(obj.vehicleID,entity.data.wsmp,2); %field2: vehicleID
                    entity.data.wsmp=app_msg2wsmp(obj.spSCHInfo,entity.data.wsmp,3); % field3: service provider SCH number
                    entity.data.wsmp=app_msg2wsmp(obj.svcInfo, entity.data.wsmp,4); % field4: service type
                    
                    
                    disp(['    Vehicle' num2str(obj.vehicleID) '_APP sends WSA to MAC layer.']);
                    events =[events obj.eventForward('storage',3,0)];
                case 'startDriving'      
%                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms, ' 'Vehicle: ' num2str(obj.vehicleID) ' startDriving, next--> eventTimer(driving)']);       
                    out=zeros(100,10);
                    out=fcn_initInfo('get',obj.lane);
            
                    [n,~]=size(out);
            
                    for i=1:n
                        if out(i)~=0    
                            fcn_carLocalDB('set',obj.vehicleID,out(i,1),out(i,2),out(i,3),out(i,4),out(i,5),out(i,6),out(i,7));
                        end
                    end

                    obj.startDrivingTag=1;
                    events=obj.eventTimer('driving',0);
                case 'laneChangingRequestTimeout'
%                     disp(num2str(entity.data.priority));
                    entity.data.priority=111; % cancelTimer doesn't work.
                                              % Have to iterate storage and destroy this entity to stop timer. 
                                              % other entity has priority
                                              % 0-7, this one's priority is
                                              % 111. When iterating,
                                              % destroy entity with
                                              % priority of 100 could stop
                                              % timer. 
                                              
                    events=obj.eventTimer('laneChangingRequestTimeout',0.005+100/1000);
%                     obj.getCurrentTime()*1000
                case 'BSMgen'                    
%                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms, ' 'Vehicle: ' num2str(obj.vehicleID) 'generate BSM--> curPos: ' num2str(obj.curPositionX) ' curSpeed: ' num2str(obj.curSpeedX) ' curAcc: ' num2str(obj.acceleration)]);                    
                    % BSM format:
                        % 1. message type: BSM
                        % 2. vehicle ID
                        % 3. position X
                        % 4. position Y
                        % 5. lane number
                        % 6. speed X
                        % 7. speed Y
                        % 8. acceleration
                    payloadlength=evalin('base','payloadLength');
                    entity.data.wsmp=ones(1,payloadlength);
                    entity.data.VehicleID=obj.vehicleID;
                    entity.data.priority=5;                    
                    entity.data.dstAddress=0;
                    
                    entity.data.wsmp=app_msg2wsmp(1,entity.data.wsmp,1); % message type 1: BSMs
                    entity.data.wsmp=app_msg2wsmp(obj.vehicleID,entity.data.wsmp,2);
                    entity.data.wsmp=app_msg2wsmp(obj.curPositionX,entity.data.wsmp,3);
                    entity.data.wsmp=app_msg2wsmp(obj.curPositionY,entity.data.wsmp,4);
                    entity.data.wsmp=app_msg2wsmp(obj.lane,entity.data.wsmp,5);         
                    entity.data.wsmp=app_msg2wsmp(obj.curSpeedX,entity.data.wsmp,6);
                    entity.data.wsmp=app_msg2wsmp(obj.curSpeedY,entity.data.wsmp,7);
                    entity.data.wsmp=app_msg2wsmp(obj.acceleration,entity.data.wsmp,8);
                                                                                                        
                    if obj.curPositionX<obj.mapborder   % forward to tx buffer                     
                        events=[events obj.eventForward('storage',3,0) obj.eventGenerate(1,'BSMgen',0.1,300)];
                    else % if greater than border, destroy entity               
                        events=[events obj.eventDestroy() obj.eventGenerate(1,'BSMgen',0.1,300)];
                    end
                case 'RDTgen'
                    payloadlength=evalin('base','payloadLength');
                    entity.data.wsmp=ones(1,payloadlength);
                    entity.data.VehicleID=obj.vehicleID;
                    entity.data.priority=7;                    
                    entity.data.dstAddress=obj.dstAddress;
                    entity.data.channelNum=obj.spSCHInfo;
                    % 1. message type
                    % 2. vehicle ID
                    % 3. position X
                    % 4. Speed X
                    % 5. acceleration
                    
                    entity.data.wsmp=app_msg2wsmp(2,entity.data.wsmp,1); % message type 2: EMG-->RDT
                    entity.data.wsmp=app_msg2wsmp(obj.vehicleID,entity.data.wsmp,2);
                    entity.data.wsmp=app_msg2wsmp(obj.curPositionX,entity.data.wsmp,3);
                    entity.data.wsmp=app_msg2wsmp(obj.curSpeedX,entity.data.wsmp,4);       %obj.speed
                    entity.data.wsmp=app_msg2wsmp(obj.acceleration,entity.data.wsmp,5);       % obj.acceleration  
                                                             
                    events=[events obj.eventForward('storage',3,0)];
                    
                    
%                     if obj.appTXTEnable && obj.vehicleID==1 
                        disp(['T = ' num2str(obj.getCurrentTime()*1000) 'ms, Vehicle' num2str(obj.vehicleID) '_APP generates lane changing REQUEST <' num2str(obj.dstAddress) '> for SCH' num2str(entity.data.channelNum)]);
%                     end
                    
            
                    if strcmp(obj.brakeMode,'ConLaneChange')
                        events=[events obj.eventGenerate(1,'laneChangingRequestTimeout',0,10)];
                    end
                    
                case 'RDTreply'
%                     if obj.appTXTEnable && obj.vehicleID==1 
                        disp(['T = ' num2str(obj.getCurrentTime()*1000) 'ms, Vehicle' num2str(obj.vehicleID) '_APP generates lane changing REPLY.']);
%                     end
                    payloadlength=evalin('base','payloadLength');
                    entity.data.wsmp=ones(1,payloadlength);
                    entity.data.VehicleID=obj.vehicleID;
                    entity.data.priority=7;                    
                    entity.data.dstAddress=obj.dstAddress;
                    entity.data.channelNum=obj.suSCHInfo;
                    
                    entity.data.wsmp=app_msg2wsmp(3,entity.data.wsmp,1); % message type 3: lane changing reply
                    entity.data.wsmp=app_msg2wsmp(obj.vehicleID,entity.data.wsmp,2);
                    entity.data.wsmp=app_msg2wsmp(obj.laneChangingAns,entity.data.wsmp,3); % lane changing reply answer: 0>no, 1>yes
                                        
                    events=[events obj.eventForward('storage',3,0.000001*obj.vehicleID)];
                    
            end
        end
        
        function [entity,events]=payloadEntry(obj,storage,entity,~)
            events=obj.initEventArray;
            coder.extrinsic('num2str');
            coder.extrinsic('fcn_carGlobalDB');
            coder.extrinsic('app_wsmp2msg_mex');            
            coder.extrinsic('fcn_carLocalDB');  
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('app');
            
            switch storage                
                case 2 % rx buffer
                    if obj.curPositionX < obj.mapborder
                                       
                        msgType=1;
                        msgType=app_wsmp2msg_mex(entity.data.wsmp,1);
                        
                        switch msgType
                            case 1 % BSM
%                                 disp('rcv BSM');
                                events = obj.rcvBSM(entity);
                            case 2 % EMG
                                events = obj.rcvEMG(entity);
                            case 3 % replyRDT 
                                events = obj.rcvRDT(entity);
                            case 111 % MGM
                                events = obj.rcvMGM(entity);
                            case 222 % WSA
                                events = obj.rcvWSA(entity);
                            case 55
%                                 entity.data.channelNum
                                if obj.vehicleID == 2
                                    disp('++++++++++++++++++++++++++++++++++++++++receive test message++++++++++++++++++++++++++++++++++');
                                end
%                             otherwise
%                                 events=[];   
                        end                                                
                    else % ignore messages from the car out of map
                        events=obj.eventDestroy();
                    end
                case 3 % tx buffer
                  
%                     disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms, ' 'car ' num2str(obj.vehicleID) ' sent ' ]);                    
                    fcn_carGlobalDB(obj.vehicleID,obj.curPositionX,obj.curPositionY,obj.lane);   % set current position info to Global Database
                    events=obj.eventForward('output',1,0);
            end
        end
        
        function [entity,events,next]=payloadIterate(obj,~,entity,tag,~)
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('app');
            next=false;
            events=obj.initEventArray;
            tag=tag(tag~=0);
            switch tag
                case 'cancelLaneChangingRequestTimer'                    
                    if entity.data.priority==111
%                         disp('--LaneChangingRequestTimer canceled--');
                        events=obj.eventDestroy();
                        next=false;
                    else
                        next=true;
                    end                                    
            end
        end 
        
        function [entity,events]=payloadTimer(obj,~,entity,tag)       
            coder.extrinsic('num2str');
            coder.extrinsic('evalin');
            coder.extrinsic('fcn_carGlobalDB');
%             coder.extrinsic('plotCAV');
            %coder.extrinsic('str2num');
            coder.extrinsic('app_unicastAddressConv');
            coder.extrinsic('strcat');
            coder.extrinsic('fcn_CAVrecord');
            coder.extrinsic('fcn_eventsCount');            
            fcn_eventsCount('app');
            events=obj.initEventArray;                                    
            tag=tag(tag~=0);
            switch tag
                case 'driving'
                    events=[obj.driving(entity) obj.eventTimer('driving',0.1)];
                    if obj.vehicleID==1 && obj.isUIon==0 && (abs(fix(obj.getCurrentTime())-obj.getCurrentTime())<0.1)                         
                        disp(['sim time: ' num2str(obj.getCurrentTime()) 's']);
                    end
                case 'laneChangingRequestTimeout'
                    if obj.appTXTEnable 
                        disp(['UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUT= ' num2str(obj.getCurrentTime()*1000) 'ms, ' 'Vehicle: ' num2str(obj.vehicleID) ' lane changing request timeout, brake']);
                    end
                    if obj.carStatus==1
                        disp(['Lane Changing is undergoing, do nothing.']);
                    elseif obj.carStatus==0                       
                        obj.LCtimeTag=0;
                        fcn_CAVrecord('logLCTimeoutNum',obj.vehicleID);
                        obj.brake();  
                    end
                case 'restartDriving'
                    obj.acceleration=20/3.6;   
                    if obj.appTXTEnable && obj.vehicleID==1 
                        disp([num2str(obj.acceleration) 'restartDriving' ]);
                    end
                case 'regularBrake'          
                    obj.reactPeriodTag=0;                    
                    if obj.appTXTEnable && obj.vehicleID==1 
                        disp(['T=' num2str(obj.getCurrentTime()*1000) 'ms, ' 'Car' num2str(obj.vehicleID) ': ......REACTION PERIOD ENDED.......']);                                       
                    end
                    switch obj.brakeMode                                   
                        case 'ConLaneChange'                                               
                            events=obj.conservativeLaneChanging;                                           
                        case 'PerLaneChange'                               
                           events=obj.performanceLaneChanging;                            
                        case 'NonLaneChange'                            
                            obj.brake;                                                       
                    end
                case 'EMGBrake'          
                    obj.reactPeriodTag=0;
                    if obj.appTXTEnable && obj.vehicleID==1 
                        disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms, ' 'Vehicle' num2str(obj.vehicleID) ': ......EMG REACTION PERIOD ENDED......']);
                        disp(' ');
                    end
                    switch obj.brakeMode                                   
                        case 'EMGconLaneChange'                                               
                            events=obj.conservativeLaneChanging;                                           
                        case 'EMGperLaneChange'                               
                           events=obj.performanceLaneChanging;                            
                        case 'NonLaneChange'                            
                            obj.brake;                                                       
                    end
            end
        end
        
    end
    
    methods (Access=private)
        %% car global database related method(s)        
        function events=carCollisionCheck(obj)                  
            coder.extrinsic('num2str');
            coder.extrinsic('fcn_carGlobalDB');
            events=obj.initEventArray;
%             disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms, ' 'Vehicle: ' num2str(obj.vehicleID) ' carCollisionCheck'])                                             
            fcn_carGlobalDB(obj.vehicleID,obj.curPositionX,obj.curPositionY,obj.lane);   % set current position info to Global Database
            
            out=ones(1,2)*1000;                                                      % predefine 'out' type for code generation
            out=fcn_carGlobalDB(obj.vehicleID);                                          % obtain distances to the cars front and back from Global database
                                                                                        % out(1) distance to front car; out(2) distance to back car
            % involve in an accident
            if (out(1)<5||out(2)<5) && obj.carStatus~=4
                obj.carStatus=4;
            end
                                    
            %%                                                                                        
            if out(2)>5 && obj.accidentTag==1 % leave the accident zone, reset accident tag                                                        
                obj.accidentTag=0;            
                obj.carStatus=0;
            end
                                    
            if out(1)<5 %hit another car            
                if obj.appTXTEnable && obj.vehicleID==1 
                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms, ' 'Vehicle ' num2str(obj.vehicleID) ' on position ' num2str(obj.curPositionX) ' HITs>>> vehicle. distance: ' num2str(out(1))]);                                                        
                end
                obj.carAccidentTag=1;
                obj.curSpeedX=0;                    
                events=obj.eventGenerate(1,'EMGgen',0.1,300);                
%             elseif out(1)>max([10, obj.curSpeedX])    % restart driving after hitting another car        
            elseif out(1)>10 && obj.curSpeedX==0 && obj.carAccidentTag==1  % restart driving after hitting another car
                obj.carAccidentTag=0;
                obj.acceleration=10/3.6;      
                if obj.appTXTEnable && obj.vehicleID==1 
                    disp(['Vehicle ' num2str(obj.vehicleID) 'restart driving after hitting another car at acceleration ->' num2str(obj.acceleration)]);
                end
            end
                                                            
            if out(2)<5 && obj.accidentTag==0 % hitted by another car            
                if obj.appTXTEnable && obj.vehicleID==1 
                    disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms, ' 'Vehicle ' num2str(obj.vehicleID) ' on position ' num2str(obj.curPositionX) ' is >>>HIT by another vehicle. distance: ' num2str(out(2))]);                                                        
                end
                fcn_carGlobalDB('accident',obj.getCurrentTime()*1000);                
                obj.accidentTag=1;                    
                obj.curSpeedX=0;                     
                obj.acceleration=0;                
                events=obj.eventTimer('restartDriving', obj.carAccidentProcessingPeriod);                
            end                        
        end     
        
        function trafficLight(obj)
            
            coder.extrinsic('num2str');
            coder.extrinsic('fcn_carGlobalDB');            
                        
            speed=obj.curSpeedX/3.6;  % convert speed to meters/s            
            estBrakeTrail=obj.reactDelay*speed+speed^2/(2*5);
%             brakeTrail=obj.reactDelay*speed+speed^2/(2*6.5);
            intersectionBorder=90*(obj.mapborder/200);
            dist2crossing=intersectionBorder-obj.curPositionX;
            deceleration=(0-speed^2)/(2*dist2crossing);                                                          
            
            light=obj.checkTrafficLight();
            
            if obj.curPositionX>=50 && obj.curPositionX<=92*(obj.mapborder/200)                
                if obj.carStatus~=2                
                    switch light
                        case 0 %Green light
                            if obj.appTXTEnable && obj.vehicleID==1 
                                disp(['T=' num2str(obj.getCurrentTime()) ' CAR ' num2str(obj.vehicleID) ' detects GREEN light! carStatus**** ' num2str(obj.carStatus)]);
                            end
                        case 1 % Yellow light                           
                            if estBrakeTrail<=dist2crossing && dist2crossing<=obj.distance
                                obj.carStatus=2;
                                if obj.appTXTEnable && obj.vehicleID==1 
                                    disp(['T=' num2str(obj.getCurrentTime()) 'CAR ' num2str(obj.vehicleID) '{' num2str(obj.carStatus) '} detects YELLOW light! Convert to INTERSECTION mode']);
                                end
                                
                            else
                                if obj.appTXTEnable && obj.vehicleID==1 
                                    disp(['T=' num2str(obj.getCurrentTime()) 'CAR ' num2str(obj.vehicleID) '{' num2str(obj.carStatus) '} detects YELLOW light, TOO LATE for braking! Keep driving!!']);
                                end
                            end
                            
                        case 2 % Red light      
                            if obj.appTXTEnable && obj.vehicleID==1 
                                disp(['T=' num2str(obj.getCurrentTime()) ' CAR ' num2str(obj.vehicleID) ' detects RED light! foresee distance: ' num2str(obj.curPositionX+obj.distance) ' intersectionBorder ' num2str(intersectionBorder)]);
                            end
                            if obj.curPositionX+obj.distance>intersectionBorder+1 && obj.curPositionX < intersectionBorder                                
                                obj.carStatus=2;                                
                                if obj.appTXTEnable && obj.vehicleID==1 
                                    disp(['T=' num2str(obj.getCurrentTime()) 'CAR ' num2str(obj.vehicleID) '{' num2str(obj.carStatus) '}  Convert to INTERSECTION mode']);
                                end
                            end
                            
                        case 4 % car accident
                            
                    end
                else % carStatus==2, first car at the intersection
                    if obj.curSpeedX~=0                         
                        if light~=0 % not green light, brake
                            obj.acceleration=min(deceleration,obj.acceleration);
                            if obj.appTXTEnable && obj.vehicleID==1 
                                disp(['T=' num2str(obj.getCurrentTime()) ' CAR ' num2str(obj.vehicleID) '{' num2str(obj.carStatus) '} SLOW DOWN at the intersection. Deceleration: ' num2str(obj.acceleration) 'm/s^2']);
                            end
                        else
                            obj.carStatus=0;
                            obj.acceleration=20/3.6;
                            if obj.appTXTEnable && obj.vehicleID==1 
                                disp(['T=' num2str(obj.getCurrentTime()) ' CAR ' num2str(obj.vehicleID) '{' num2str(obj.carStatus) '} detects GREEN light, switch to carFollowingMode']);                            
                            end
                        end                    
                    else % speed ==0, waiting for green light
                        if light==0 % green light, start driving                            
                            obj.acceleration=20/3.6;
                            obj.carStatus=0;
                            if obj.appTXTEnable && obj.vehicleID==1 
                                disp(['T=' num2str(obj.getCurrentTime()) ' CAR ' num2str(obj.vehicleID) '{' num2str(obj.carStatus) '} RESTART at the intersection.']);
                            end
                        end                    
                    end                                
                end
            
            end       
        end        
        
        %% message processing methods
        function events=rcvBSM(obj,entity)
            coder.extrinsic('app_wsmp2msg_mex');
            coder.extrinsic('fcn_carLocalDB');
            coder.extrinsic('fcn_carGlobalDB');
            coder.extrinsic('num2str');
            events=obj.initEventArray();
            
            othervehicleID=1;            
            othervehicleID=app_wsmp2msg_mex(entity.data.wsmp,2);                                                            
            posX=1;            
            posX=app_wsmp2msg_mex(entity.data.wsmp,3);                                                            
            posY=1;            
            posY=app_wsmp2msg_mex(entity.data.wsmp,4);                                    
            rcvLane=1;            
            rcvLane=app_wsmp2msg_mex(entity.data.wsmp,5);
            rcvSpeedX=1;
            rcvSpeedX=app_wsmp2msg_mex(entity.data.wsmp,6);
            rcvSpeedY=1;
            rcvSpeedY=app_wsmp2msg_mex(entity.data.wsmp,7);
            rcvAcc=1;
            rcvAcc=app_wsmp2msg_mex(entity.data.wsmp,8);
            
            if obj.appTXTEnable 
                disp(['Vehicle ' num2str(obj.vehicleID) ' at lane<' num2str(obj.lane) '> receives BSM from car ' num2str(othervehicleID) ' at lane<' num2str(rcvLane) '>' ' acceleration ' num2str(obj.acceleration)]);
            end
            
            if obj.lane==rcvLane                               
                fcn_carLocalDB('set',obj.vehicleID,obj.vehicleID,obj.curPositionX,obj.curPositionY,obj.lane,obj.curSpeedX,obj.curSpeedY,obj.acceleration);                
                fcn_carLocalDB('set',obj.vehicleID,othervehicleID,posX,posY,rcvLane,rcvSpeedX,rcvSpeedY,rcvAcc);                                           
                if obj.appTXTEnable 
                    disp(['T=' num2str(obj.getCurrentTime()*1000) 'ms. car' num2str(obj.vehicleID) ' at ' num2str(obj.curPositionX) ' ' num2str(obj.curPositionY) ' detect car ' num2str(othervehicleID) ' at ' num2str(posX) ' ' num2str(posY) ' ']);               
                end
                if obj.startDrivingTag==1 && obj.reactPeriodTag==0
                    switch obj.carStatus
                        case 0 % carfollowing
                            if obj.appTXTEnable && obj.vehicleID==1
                                disp(['CAR ' num2str(obj.vehicleID) ' carFollowingMode at speed of ' num2str(obj.curSpeedX) ]);
                            end
                            events=obj.carFollowingAlgorithm();
                        case 1 % lanechanging
%                             disp('laneChangingMode');
                            events = obj.changeLane;                             
                        case 2 % intersection
%                             disp(['Vehicle ' num2str(obj.vehicleID) ' on INTERSECTION mode ++++++ at postion of ' num2str(obj.curPositionX) 'speed: ' num2str(obj.curSpeedX)]);
                            if obj.curSpeedX/3.6<0.1 && obj.acceleration<0
                                obj.curSpeedX=0;
                            end
                    end
                end                               
            else
                events=obj.eventDestroy();
            end
            
            
        end
        
        function events=rcvEMG(obj,entity)
            coder.extrinsic('app_wsmp2msg_mex');
            coder.extrinsic('num2str');
            events=obj.initEventArray;
            
            srcAddress=0;            
            srcAddress=app_wsmp2msg_mex(entity.data.wsmp,2);                                                
            
            posX=1;            
            posX=app_wsmp2msg_mex(entity.data.wsmp,3);                        
                                    
            rcvSpeedX=1;            
            rcvSpeedX=app_wsmp2msg_mex(entity.data.wsmp,4);
                                    
            rcvACC=1;            
            rcvACC=app_wsmp2msg_mex(entity.data.wsmp,5);          
            
            if posX<=obj.curPositionX % car in front 
%                 if obj.appTXTEnable && obj.vehicleID==1 
                    disp(['T = ' num2str(obj.getCurrentTime()*1000) 'ms, Vehicle' num2str(obj.vehicleID) '_APP receives lane changing request BACK <<<<<car' num2str(srcAddress) '>'])
%                 end
                calDist=(obj.curSpeedX/3.6+obj.acceleration)*2+obj.curPositionX-posX-(rcvSpeedX/3.6+rcvACC)*2;
                deceleration=(0-(rcvSpeedX/3.6)^2)/(2*(calDist));                
                if deceleration>-9.8*obj.fractionCoe   %v_o*t+0.5*a*t^2=distance; t=2s in the case.
                    obj.laneChangingAns=1;
                else
                    obj.laneChangingAns=0;
                end
            else                     % car at back
%                 if obj.appTXTEnable && obj.vehicleID==1 
                    disp(['T = ' num2str(obj.getCurrentTime()*1000) 'ms, Vehicle' num2str(obj.vehicleID) '_APP receives lane changing request from FRONT <<<<<car' num2str(srcAddress) '>'])
%                 end
                calDist=rcvSpeedX/3.6*2+posX-obj.curPositionX-(obj.curSpeedX/3.6*2+0.5*obj.acceleration*2^2);
                deceleration=((rcvSpeedX/3.6)^2-(obj.curSpeedX/3.6)^2)/(2*calDist);
                if calDist>(obj.curSpeedX/3.6+2*obj.acceleration)*3.6 % greater than safety distance
                    obj.laneChangingAns=1;
                else
                    if deceleration<=-9.8*obj.fractionCoe
                        obj.laneChangingAns=0;                                            
                    else
                        obj.laneChangingAns=1;
                        obj.acceleration=min(0,obj.acceleration);       
                    end
                    
                end
            end
            
            if strcmp(obj.brakeMode,'ConLaneChange')
                obj.dstAddress=srcAddress;
                events=obj.eventGenerate(1,'RDTreply',0,10);            
            end
            
        end
                
        function events=rcvRDT(obj,entity)
            coder.extrinsic('num2str');
            coder.extrinsic('app_wsmp2msg_mex');
            events=obj.initEventArray;
            
            rcvCarID=0;
            rcvCarID=app_wsmp2msg_mex(entity.data.wsmp,2);
            
            laneChangingReply=0;
            laneChangingReply=app_wsmp2msg_mex(entity.data.wsmp,3);
            
            if laneChangingReply==1
                if obj.appTXTEnable && obj.vehicleID==1 
                    disp(['T = ' num2str(obj.getCurrentTime()*1000) 'ms, Vehicle' num2str(rcvCarID) ' replies to Vehicle' num2str(obj.vehicleID) ': lane changing request permited ^_^ ']);
                end
                disp(['T = ' num2str(obj.getCurrentTime()*1000) 'ms, Vehicle' num2str(obj.vehicleID) '_APP receives lane changing reply from Vehicle' num2str(rcvCarID) ': PERMITED! ^_^ ']);
                
                [a,b]=ismember(rcvCarID,obj.RDTaddressBook);
                if a==1
                    obj.RDTaddressBook(b)=0;
                    if sum(obj.RDTaddressBook)==0
                       events = obj.changeLane;
                        events=[events obj.eventIterate(1,'cancelLaneChangingRequestTimer',1)];
                    else
                        if obj.appTXTEnable && obj.vehicleID==1 
                            disp(['=============> Keeping waiting for reply from car' num2str(sum(obj.RDTaddressBook))])
                        end
                        
                    end
                end                                
            else
                if obj.appTXTEnable && obj.vehicleID==1 
                    disp(['T=' num2str(obj.getCurrentTime()*1000) 'ms, car' num2str(rcvCarID) ' reply to car' num2str(obj.vehicleID) ': lane changing request prohibited o_o!! ']);                       
                end
                obj.brake();
                events=[events obj.eventIterate(1,'cancelLaneChangingRequestTimer',1)];
            end
        end  
        
        function events=rcvMGM(obj,entity) % management frame
            % entity.data.wsmp(1), message type--> management, 112
            % entity.data.wsmp(2), message content --> 111, 112.
            
            coder.extrinsic('app_wsmp2msg_mex');
            coder.extrinsic('num2str');
            coder.extrinsic('strcat');            
            coder.extrinsic('app_unicastAddressConv');
            events=obj.initEventArray;
            
            if obj.appTXTEnable && obj.vehicleID==1 
                disp('receive MGM message');
            end                                    
                        
            msgType=1;
            msgType=app_wsmp2msg_mex(entity.data.wsmp,1);
            msg2=1;
            msg2=app_wsmp2msg_mex(entity.data.wsmp,2);
            
            switch msgType
                case 111 % management message
                    if msg2==abs('A') % ACKed
                        frontAddress=0;
                        backAddress=0;
                        
                        dstAdd=num2str(obj.dstAddress);

                        frontAddress=str2double(dstAdd(2:4));
                        backAddress=str2double(dstAdd(5:7));
                        
                        if frontAddress~=0
                            if obj.appTXTEnable && obj.vehicleID==1 
                                disp('front car ack received');
                            end
                            if obj.RDTaddressBook(2)~=0
                                if obj.appTXTEnable && obj.vehicleID==1 
                                    disp('back car request generated');
                                end
                                obj.dstAddress=str2double(strcat('1', app_unicastAddressConv(0),app_unicastAddressConv(obj.RDTaddressBook(2))));                                                                
                                events=obj.eventGenerate(1,'RDTgen',0,10);                                                     
                            else
                                if obj.appTXTEnable && obj.vehicleID==1 
                                    disp('no back car, change lane');
                                end
                                events = obj.changeLane;
                            end
                            
                        elseif backAddress~=0
                            if obj.appTXTEnable && obj.vehicleID==1 
                                disp('back car acked successfully, change lane');
                            end
                            events = obj.changeLane;
                        end
                        
                        
                    elseif msg2==abs('U') %UnACKed
                        obj.brake();
                    end
                    
            end
            
            
        end
        
        function events = rcvWSA(obj,entity)
            coder.extrinsic('app_wsmp2msg_mex');       
            coder.extrinsic('num2str');
            svcVehicleID = 0;
            svcVehicleID = app_wsmp2msg_mex(entity.data.wsmp,2);                        
            
            schinfo = 0; % SCH number                       
            schinfo=app_wsmp2msg_mex(entity.data.wsmp,3);                            
            obj.suSCHInfo = schinfo;
            
            service = 0; %service type
            service = app_wsmp2msg_mex(entity.data.wsmp,4);
            obj.svcInfo = service;
            
            disp(['T = ' num2str(obj.getCurrentTime()*1000) 'ms, Vehicle' num2str(obj.vehicleID) '_APP receives WSA from Vehicle ' num2str(svcVehicleID) '. Tune to SCH' num2str(obj.suSCHInfo) ' in next SCHI for service' num2str(obj.svcInfo) ]);
            events = obj.eventGenerate(5,'rcvWSA',0,300);
        end
        
        %% vehicle action methods                   
        function events=driving(obj,~)            
            coder.extrinsic('fcn_carGlobalDB');
            coder.extrinsic('num2str');
%             disp(['T= ' num2str(obj.getCurrentTime()*1000) 'ms, ' 'Vehicle: ' num2str(obj.vehicleID) ' driving'])
            events=obj.initEventArray;
                        
            obj.curSpeedX=obj.curSpeedX+obj.acceleration*3.6*0.1;                        
            obj.curSpeedX=max(obj.curSpeedX,0);
            obj.curSpeedX=min(obj.curSpeedX,obj.speedLimit);             
            
            if obj.curPositionX<obj.mapborder % car in the MAP
                events=obj.carCollisionCheck();
                
                if strcmp(obj.roadType,'crossRD')
                    obj.trafficLight();
                end
                events = [events obj.plotUI()];
            else                              % car out of the MAP
                obj.curPositionX=obj.mapborder*3;                
                obj.curSpeedX=0;                
                obj.acceleration=0;                
                fcn_carGlobalDB(obj.vehicleID,obj.curPositionX,obj.curPositionY,obj.lane);                                                
                %TODO Ask about it with LE
                o=double(1);                
                o=fcn_carGlobalDB(obj.vehicleID,obj.mapborder);                                                            
                if o==1                
                    obj.accidentTag=0;                                                
                    obj.distance=1000;                                                
                    obj.slowdownTag=0;                                        
                    obj.frontCarID=0;                                                                                
                    obj.curPositionX=0;                                                            
                    obj.curSpeedX=obj.initVelocity;                                                            
                    obj.acceleration=10/3.6;    
                    obj.decelerationTag=0;
%                     disp([num2str(obj.acceleration) 'out of map']);
                    fcn_carGlobalDB(obj.vehicleID,obj.curPositionX,obj.curPositionY,obj.lane);
                end                                                
            end                                     
        end          
                        
        function events = plotUI(obj)         
            coder.extrinsic('num2str');
            coder.extrinsic('plotCAV');
            coder.extrinsic('fcn_CAVrecord');
            events = obj.initEventArray;
            
            fcn_CAVrecord('save',obj.vehicleID,obj.curSpeedX,obj.getCurrentTime());
%             avgSpeed=fcn_CAVrecord('get',obj.vehicleID);
                                                          
            obj.curPositionX=obj.curPositionX+obj.curSpeedX/3.6*0.1;                                                                                                                     
            obj.curPositionY=obj.curPositionY+obj.curSpeedY*0.1;            
            
            if abs(obj.curPositionY-obj.tgPosY)<0.01 && abs(obj.curPositionY-obj.tgPosY)~=0
%                 if obj.appTXTEnable && obj.vehicleID==1                                 
                    disp(['T= ' num2str(obj.getCurrentTime()*1000) ':' 'Car' num2str(obj.vehicleID) '--LANE--CHANGING--DONE--!']);
%                 end
                obj.carStatus=0;
                obj.curPositionY=obj.tgPosY;                                    
                obj.decelerationTag=0;
                obj.curSpeedY=0;  
            end                             
%             disp(['<--Speed-->: vehicle:' num2str(obj.vehicleID)  ' acceleration:' num2str(obj.acceleration) 'speed: ' num2str(obj.curSpeedX)]);                                                   
            if obj.isUIon
                plotCAV(obj.vehicleID,obj.lane,obj.curPositionX,obj.curPositionY,obj.getCurrentTime(),obj.roadType);                                
            end
        end
                
        function brake(obj)
            coder.extrinsic('num2str');
            deceleration=((obj.localDBinfo(1,5)/3.6)^2-(obj.curSpeedX/3.6)^2)/(2*(obj.distance-10));
            if deceleration<ceil(-9.8*obj.fractionCoe)
                obj.acceleration=max(deceleration,-9.8*obj.fractionCoe);
            else
                obj.acceleration=min(obj.acceleration,deceleration);
            end
            
            obj.acceleration=min(obj.acceleration,-1);            
            if obj.appTXTEnable && obj.vehicleID==1 
                disp(['=============> Car' num2str(obj.vehicleID) ': Braking============================================>deceleration: ' num2str(obj.acceleration)]);
            end
        end
        
        function events = changeLane(obj)
            coder.extrinsic('num2str');   
            coder.extrinsic('fcn_CAVrecord');
            events = obj.initEventArray();
            if obj.carStatus==0
%                 if obj.appTXTEnable && obj.vehicleID==1 
                    disp(['T = ' num2str(obj.getCurrentTime()*1000) 'ms, Vehicle' num2str(obj.vehicleID) '^^STARTS^^LANE^^CHANGING^^']);                                            
%                 end
                                                                
                LCLatency=obj.getCurrentTime()*1000-obj.LCtimeTag;
                
                disp(['====Vehicle' num2str(obj.vehicleID) ': Current Time: ' num2str(obj.getCurrentTime()*1000) 'ms - LC_begin_timeTag ' num2str(obj.LCtimeTag) 'ms = LCLatency' num2str(LCLatency) 'ms====']);
                
                fcn_CAVrecord('logLCLatency',obj.vehicleID,LCLatency);
                obj.LCtimeTag=0;
%                 disp('set 0 line 956');
                obj.carStatus=1;            
                obj.curSpeedY=4-mod((obj.curPositionY/4),2)*8;
                obj.curSpeedY=obj.curSpeedY/2;
%                 events = [events obj.resetMCinfo()];
            end
        end
        
        %%
        function events=carFollowingAlgorithm(obj)            
            events=obj.initEventArray;
            coder.extrinsic('fcn_carLocalDB');
            coder.extrinsic('num2str');
            out=ones(2,2)*1000;                        
            info=zeros(2,7);                
            [out,info]=fcn_carLocalDB('get',obj.vehicleID);       
                % out: 2X2 array
                    %frontCar-distance frontCarID
                    %backCar-distance backCarID  
                %info:  2X7 array
                    %frontCarID,latitude,longitude,lane,speedX,speedY,acceleration
                    %backCarID,latitude,longitude,lane,speedX,speedY,acceleration  
            obj.distance=out(1,1);
            maxDecel=-6.5; % m/s^2, -6.5 is the typical max deceleration from the braking reference. Calculated from brake distance.
            brakeDist=obj.curSpeedX/3.6*obj.reactDelay+(obj.curSpeedX/3.6)^2/(2*abs(maxDecel));                        
            
            if obj.distance-10<=brakeDist % enter react period, then start lane changing or braking                
                if obj.decelerationTag==0 % react period only happen once per each brake activity
                    
                    if info(1,1)~=0 && obj.appTXTEnable==1 
                        disp(' ');
                        disp(['T=' num2str(obj.getCurrentTime()*1000) 'ms, {Car' num2str(obj.vehicleID) '- ' num2str(obj.distance-10) 'm -> Car' num2str(info(1,1)) '}  < {brakeDist: ' num2str(brakeDist) 'm}...... Enter reaction period.......']);
                    end
                    
                    emgBrakeDist=obj.curSpeedX/3.6*obj.reactDelay+(obj.curSpeedX/3.6)^2/(2*abs(-9.8*obj.fractionCoe));
                    deceleration=(0-(obj.curSpeedX/3.6)^2)/(2*(emgBrakeDist+obj.distance-10));                    
                    if deceleration>-6.5
                        events=obj.eventTimer('regularBrake',obj.reactDelay);  
                        obj.reactPeriodTag=1;
                    else
                        events=obj.eventTimer('EMGBrake',obj.reactDelay);                                                    
                        obj.reactPeriodTag=1;
                    end                                        
                    
                    obj.decelerationTag=1;%                             
                end
            else % distance > brakeDist: 1. no car in front; 2. just finish braking 3. regular approach to front car       
                if obj.appTXTEnable && obj.vehicleID==1
                    disp(['T=' num2str(obj.getCurrentTime()*1000) 'ms, ' 'vehicle' num2str(obj.vehicleID) 'is ' num2str(obj.distance-10) ' meters to front car' num2str(info(1,1)) '> brake distance ' num2str(brakeDist) 'at speed of ' num2str(obj.curSpeedX)]);                           
                end                             
                if info(1,1)~=0
                    if obj.decelerationTag==1
                        obj.decelerationTag=0;
                        if obj.appTXTEnable && obj.vehicleID==1 
                            disp(['T=' num2str(obj.getCurrentTime()*1000) 'ms, Car' num2str(obj.vehicleID) '- ' num2str(obj.distance-10) 'm -> Car' num2str(info(1,1)) 'GREATER THAN>>> brakeDist-' num2str(brakeDist) 'ms -Deceleration Ended!!']);
                        end
                    end                    
                    deceleration=((info(1,5)/3.6)^2-(obj.curSpeedX/3.6)^2)/(2*(obj.distance-brakeDist));
                    obj.acceleration=max(deceleration,maxDecel); 
%                     disp(['T=' num2str(obj.getCurrentTime()*1000) 'ms, Car' num2str(obj.vehicleID) 'update acceleration==>> ' num2str(obj.acceleration) ]);
                else % no car in front
                    obj.acceleration=20/3.6;
                end                                
            end
            
        end
        
        function laneChangingAlgorithm(obj)
            
        end
        
        function events=conservativeLaneChanging(obj)
            coder.extrinsic('num2str');            
            coder.extrinsic('fcn_carLocalDB');
            coder.extrinsic('strcat');
            coder.extrinsic('app_unicastAddressConv');
            events=obj.initEventArray;                        
            
            obj.tgPosY=obj.curPositionY+4-mod((obj.curPositionY/4),2)*8; %predict Y position
            oo=ones(2,2)*1000;         
            info=zeros(2,7);
            [oo,info]=fcn_carLocalDB('get',obj.vehicleID,obj.tgPosY);    
            
            obj.localDBdist=oo;
            obj.localDBinfo=info;                        
                       
            % obj.localDBinfo info 2X7 array                    
            % frontCarID,latitude,longitude,lane,speedX,speedY,acceleration            
            % backCarID,latitude,longitude,lane,speedX,speedY,acceleration  
                        
            predictPeriod=2;           
            % Predict front car position
            Vtf=obj.localDBinfo(1,5)/3.6+obj.localDBinfo(1,7)*predictPeriod;
            Vtf=min(Vtf,obj.speedLimit/3.6);
            frontPosPredict=obj.localDBinfo(1,2)+0.5*(obj.localDBinfo(1,5)/3.6+Vtf)*predictPeriod;             
            
            % Predict back car position
            Vtb=obj.localDBinfo(2,5)/3.6+obj.localDBinfo(2,7)*predictPeriod;
            Vtb=min(Vtb,obj.speedLimit/3.6);
            backPosPredict=obj.localDBinfo(2,2)+0.5*(obj.localDBinfo(2,5)/3.6+Vtb)*predictPeriod;                                         
            
            % predict self position
            Vt=obj.curSpeedX/3.6+obj.acceleration*predictPeriod;
            Vt=min(Vt,obj.speedLimit/3.6);
            selfPosPredict=obj.curPositionX+0.5*(obj.curSpeedX/3.6+Vt)*predictPeriod;
            
            if obj.appTXTEnable && obj.vehicleID==1                          
                disp(['T=' num2str(obj.getCurrentTime()*1000) 'ms. Vehicle' num2str(obj.vehicleID) ' predict track in the next lane']);            
            end
            
            obj.LCtimeTag=obj.getCurrentTime()*1000;
%             disp('set LCtimeTag line 1066');
            if obj.localDBdist(1,1)~=1000 && obj.localDBdist(2,1)~=1000                                
                if obj.appTXTEnable && obj.vehicleID==1 
                    disp(['=============> Car' num2str(obj.vehicleID) ' at ' num2str(obj.curPositionX) ' detects FRONT car at >>' num2str(obj.localDBinfo(1,2)) ' >> and BACK car at<<' num2str(obj.localDBinfo(2,2)) '<<on next lane']);                                                                                        
                    disp(['=============> Car' num2str(obj.vehicleID) ' predict position at ' num2str(selfPosPredict) ' FRONT car at >>' num2str(frontPosPredict) ' >> and BACK car at<<' num2str(backPosPredict) '<<']);                                                                    
                end
                if frontPosPredict-selfPosPredict>obj.distance+10 && selfPosPredict-backPosPredict>20                                                                                   
                    obj.RDTaddressBook(1)=obj.localDBdist(1,2);                                                
                    obj.RDTaddressBook(2)=obj.localDBdist(2,2);                                                
                    obj.dstAddress=str2double(strcat('1', app_unicastAddressConv(obj.RDTaddressBook(1)),app_unicastAddressConv(obj.RDTaddressBook(2))));                                                                
%                     events=obj.eventGenerate(1,'RDTgen',0,10);     
                    events = obj.sendMCmsg('conLC');
                else  
                    
                    if frontPosPredict-selfPosPredict<=obj.distance+10 && obj.appTXTEnable==1 
                        disp(['XXXXXXXXXXXXXX Front car (target lane) is too close (' num2str(frontPosPredict-selfPosPredict) 'm) <<< safe distance:' num2str(obj.distance+10)]);
                    end
                    
                    if selfPosPredict-backPosPredict<=20 && obj.appTXTEnable==1                                                               
                        disp(['XXXXXXXXXXXXXXX BACK car (target lane) is too close (' num2str(selfPosPredict-backPosPredict) 'm) <<< safe distance:' num2str(20)]);
                    end
                    
                    obj.brake();
                    if obj.appTXTEnable && obj.vehicleID==1 
                        disp(['=============> REGULAR_BRAKE (front&back) -> Vehicle' num2str(obj.vehicleID) ' curSpeed: ' num2str(obj.curSpeedX) ' curAcc: ' num2str(obj.acceleration)]);                                                                                                
                    end
                end                
            elseif obj.localDBdist(1,1)==1000 && obj.localDBdist(2,1)~=1000                                                            
                
                if obj.appTXTEnable && obj.vehicleID==1                          
                        disp(['=============> Car' num2str(obj.vehicleID) ' at ' num2str(obj.curPositionX) ' detects BACK CAR' num2str(obj.localDBinfo(2,1)) ' at <<' num2str(obj.localDBinfo(2,2)) '<<' ]);  
                        disp(['=============> Car' num2str(obj.vehicleID) ' predict position at ' num2str(selfPosPredict) '<<=<< BACK car at' num2str(backPosPredict)]);                                                                    
                end
                
                if selfPosPredict-backPosPredict>20                    
                    obj.RDTaddressBook(2)=obj.localDBdist(2,2);                                                
                    obj.dstAddress=str2double(strcat('1', app_unicastAddressConv(obj.RDTaddressBook(1)),app_unicastAddressConv(obj.RDTaddressBook(2))));                                                                
%                     events=obj.eventGenerate(1,'RDTgen',0,10);   
                    events = obj.sendMCmsg('conLC');
                else
                    if obj.appTXTEnable && obj.vehicleID==1 
                        disp(['XXXXXXXXXXXXXXX BACK car (target lane) is too close (' num2str(selfPosPredict-backPosPredict) 'm) <<< safe distance:' num2str(20)]);
                    end
                    obj.brake;
                    if obj.appTXTEnable && obj.vehicleID==1 
                        disp(['=============> REGULAR_BRAKE (back) -> Vehicle' num2str(obj.vehicleID) ' curSpeed: ' num2str(obj.curSpeedX) ' curAcc: ' num2str(obj.acceleration)]);                                                                        
                    end
                end                
            elseif obj.localDBdist(1,1)~=1000 && obj.localDBdist(2,1)==1000            
                if obj.appTXTEnable && obj.vehicleID==1 
                    disp(['=============> Car' num2str(obj.vehicleID) ' at ' num2str(obj.curPositionX) ' detects FRONT CAR' num2str(obj.localDBinfo(1,1)) '>>' num2str(obj.localDBinfo(1,2)) '>>' ]);                                                                                                                            
                    disp(['=============> Car' num2str(obj.vehicleID) ' predict position at ' num2str(selfPosPredict) '>>==>> FRONT car at ' num2str(frontPosPredict)]);                                                                    
                end
                if frontPosPredict-selfPosPredict>obj.distance+10                                                                     
                    obj.RDTaddressBook(1)=obj.localDBdist(1,2);                    
                    obj.dstAddress=str2double(strcat('1', app_unicastAddressConv(obj.RDTaddressBook(1)),app_unicastAddressConv(obj.RDTaddressBook(2))));                                                                                   
%                     events=obj.eventGenerate(1,'RDTgen',0,10);             
                    events = obj.sendMCmsg('conLC');
                else
                    if obj.appTXTEnable && obj.vehicleID==1 
                        disp(['XXXXXXXXXXXXXX Front car (target lane) is too close (' num2str(frontPosPredict-selfPosPredict) 'm) <<< safe distance:' num2str(obj.distance+10)]);
                    end
                    obj.brake;
                    if obj.appTXTEnable && obj.vehicleID==1 
                        disp(['=============> REGULAR_BRAKE (front) -> Vehicle' num2str(obj.vehicleID) ' curSpeed: ' num2str(obj.curSpeedX) ' curAcc: ' num2str(obj.acceleration)]);                                                                        
                    end
                end                
            else
                if obj.appTXTEnable && obj.vehicleID==1 
                    disp(['=============> Car' num2str(obj.vehicleID) 'No car detected on next lane, change lane now!']);                
                end
                events = obj.changeLane();       
            end                        
        end        
        
        function events=performanceLaneChanging(obj)
            coder.extrinsic('num2str');            
            coder.extrinsic('fcn_carLocalDB');
            %coder.extrinsic('str2num');
            coder.extrinsic('strcat');
            coder.extrinsic('app_unicastAddressConv');
            events=obj.initEventArray;                        
            
            obj.tgPosY=obj.curPositionY+4-mod((obj.curPositionY/4),2)*8; %predict Y position
            oo=ones(2,2)*1000;         
            info=zeros(2,7);
            [oo,info]=fcn_carLocalDB('get',obj.vehicleID,obj.tgPosY);    
            
            obj.localDBdist=oo;
            obj.localDBinfo=info;
                       
            % obj.localDBinfo info 2X7 array                    
            % frontCarID,latitude,longitude,lane,speedX,speedY,acceleration            
            % backCarID,latitude,longitude,lane,speedX,speedY,acceleration  
                        
            predictPeriod=2;  
            % Predict front car position
            Vtf=obj.localDBinfo(1,5)/3.6+obj.localDBinfo(1,7)*predictPeriod;
            Vtf=min(Vtf,obj.speedLimit/3.6);
            frontPosPredict=obj.localDBinfo(1,2)+0.5*(obj.localDBinfo(1,5)/3.6+Vtf)*predictPeriod;             
            
            % Predict back car position
            Vtb=obj.localDBinfo(2,5)/3.6+obj.localDBinfo(2,7)*predictPeriod;
            Vtb=min(Vtb,obj.speedLimit/3.6);
            backPosPredict=obj.localDBinfo(2,2)+0.5*(obj.localDBinfo(2,5)/3.6+Vtb)*predictPeriod;                                         
            
            % predict self position
            Vt=obj.curSpeedX/3.6+obj.acceleration*predictPeriod;
            Vt=min(Vt,obj.speedLimit/3.6);
            selfPosPredict=obj.curPositionX+0.5*(obj.curSpeedX/3.6+Vt)*predictPeriod;
            
            if obj.appTXTEnable && obj.vehicleID==1                          
                disp(['T=' num2str(obj.getCurrentTime()*1000) 'ms. Vehicle' num2str(obj.vehicleID) ' predict track in the next lane']);            
            end
            
            obj.LCtimeTag=obj.getCurrentTime()*1000;
            disp('set LCtimeTag 1182');
            if obj.localDBdist(1,1)~=1000 && obj.localDBdist(2,1)~=1000                                
                if obj.appTXTEnable && obj.vehicleID==1 
                    disp(['=============> Car' num2str(obj.vehicleID) ' detect front car >>> CAR and back car <<< CAR on next lane']);                                                                    
                end
                if frontPosPredict-selfPosPredict>obj.distance+10 && selfPosPredict-backPosPredict>20                                        
                    obj.RDTaddressBook(1)=obj.localDBdist(1,2);                                                
                    obj.RDTaddressBook(2)=obj.localDBdist(2,2);                                                
                    obj.dstAddress=str2double(strcat('1', app_unicastAddressConv(obj.RDTaddressBook(1)),app_unicastAddressConv(0)));                                                                
                    events=obj.eventGenerate(1,'RDTgen',0,10);                                                                        
                else
                    if frontPosPredict-selfPosPredict<=obj.distance+10 && obj.appTXTEnable==1 
                        disp(['XXXXXXXXXXXXX Front car is too close ' ' distance ' num2str(frontPosPredict-selfPosPredict) 'smaller than safe distance' num2str(obj.distance+10)]);
                    end
                    
                    if selfPosPredict-backPosPredict<=20 && obj.appTXTEnable==1                                                                
                        disp(['XXXXXXXXXXXXXX BACK car is too close ' ' distance ' num2str(selfPosPredict-backPosPredict) 'smaller than safe distance' num2str(20)]);
                    end
                    obj.brake();
                    if obj.appTXTEnable && obj.vehicleID==1 
                        disp(['REGULAR_BRAKE (front&back) -> Vehicle' num2str(obj.vehicleID) ' curSpeed: ' num2str(obj.curSpeedX) ' curAcc: ' num2str(obj.acceleration)]);                                                                        
                    end
                end                
            elseif obj.localDBdist(1,1)==1000 && obj.localDBdist(2,1)~=1000
                if obj.appTXTEnable && obj.vehicleID==1 
                    disp(['=============> Car' num2str(obj.vehicleID) ' detect back car <<< CAR' num2str(obj.localDBinfo(2,1)) 'distance:' num2str(selfPosPredict-backPosPredict)]);                                        
                end
                if selfPosPredict-backPosPredict>20                                                                                                            
                    obj.RDTaddressBook(2)=obj.localDBdist(2,2);
                    obj.dstAddress=str2double(strcat('1', app_unicastAddressConv(obj.RDTaddressBook(1)),app_unicastAddressConv(obj.RDTaddressBook(2))));                                                                
                    events=obj.eventGenerate(1,'RDTgen',0,10);                                                
                else
                    if obj.appTXTEnable && obj.vehicleID==1 
                        disp(['XXXXXXXXXXXXXX BACK car is too close ' ' distance ' num2str(selfPosPredict-backPosPredict) 'smaller than safe distance' num2str(20)]);
                    end
                    obj.brake;
                    if obj.appTXTEnable && obj.vehicleID==1 
                        disp(['=============> Car' num2str(obj.vehicleID) 'REGULAR_BRAKE (back) -> Vehicle' num2str(obj.vehicleID) ' curSpeed: ' num2str(obj.curSpeedX) ' curAcc: ' num2str(obj.acceleration)]);                                                                        
                    end
                end                
            elseif obj.localDBdist(1,1)~=1000 && obj.localDBdist(2,1)==1000            
                if obj.appTXTEnable && obj.vehicleID==1 
                    disp(['=============> Car' num2str(obj.vehicleID) 'detect front car>>>>> CAR' num2str(obj.localDBinfo(1,1)) 'distance: ' num2str(frontPosPredict-selfPosPredict)]);                                                                                                                            
                end
                if frontPosPredict-selfPosPredict>obj.distance+10
                    obj.RDTaddressBook(1)=obj.localDBdist(1,2);
                    obj.dstAddress=str2double(strcat('1', app_unicastAddressConv(obj.RDTaddressBook(1)),app_unicastAddressConv(obj.RDTaddressBook(2))));      
                    events=obj.eventGenerate(1,'RDTgen',0,10);
                else
                    if obj.appTXTEnable && obj.vehicleID==1 
                        disp(['XXXXXXXXXXXXX Front car is too close ' ' distance ' num2str(frontPosPredict-selfPosPredict) 'smaller than safe distance' num2str(obj.distance+10)]);
                    end
                    obj.brake;
                    if obj.appTXTEnable && obj.vehicleID==1 
                        disp(['=============> Car' num2str(obj.vehicleID) 'REGULAR_BRAKE (front) -> Vehicle' num2str(obj.vehicleID) ' curSpeed: ' num2str(obj.curSpeedX) ' curAcc: ' num2str(obj.acceleration)]);                                                                        
                    end
                end                
            else
                if obj.appTXTEnable && obj.vehicleID==1 
                    disp(['=============> Car' num2str(obj.vehicleID) 'no car detected on next lane']);                                            
                end
                events = obj.changeLane();                
            end  
        end
        
        function events=EMGconservativeLaneChanging(obj)
            events=obj.initEventArray;
        end
        
        function events=EMGperformanceLaneChanging(obj)
            events=obj.initEventArray;
        end
        
        function light=checkTrafficLight(obj)
            coder.extrinsic('fcn_carGlobalDB');
            trafficLight=zeros(1,2);                                    
            trafficLight=fcn_carGlobalDB('getLight');                                                                                    
            switch obj.lane                                                                
                case {1,2}                                                                                
                    light=trafficLight(1);                                                                                        
                otherwise                    
                    light=trafficLight(2);                    
            end            
        end
        
        function events = sendMCmsg(obj,activityTag)
            disp('create multi-channel message ====>');
            switch activityTag
                case 'test'
                    eventDelay = 1.5;
                    events = [obj.eventGenerate(5,'requestMCinfo', eventDelay,300),obj.eventGenerate(1,'testMultiChannel',eventDelay+0.001,500)];%  ;
                case 'conLC'
                    obj.svcInfo = 1; % ConLC, service type : 1
                    events=[obj.eventGenerate(5,'requestMCinfo', 0,300), obj.eventGenerate(1,'RDTgen',0.001,10)];   
            end
        end
        
        function events = resetMCinfo(obj)
            coder.extrinsic('num2str');
            disp(['T = ' num2str(obj.getCurrentTime()*1000) 'ms, vehicle' num2str(obj.vehicleID) ' creates resetMCinfo message.']);
            events = obj.eventGenerate(5, 'resetMCinfo', 0, 300);
        end
        
    end
    
    
    
end