function out = phy_multiChannelSensing(varargin)
% phy_multiChannelSensing(xCHno, action, ...)
%     phy_multiChannelSensing(xCHno,0,channelStatus);  %%Set channel status
%         channelStatus:  0 -- channel free 1 -- channel busy

%     phy_multiChannelSensing(xCHno, 1);   %% Get channel status


%     phy_multiChannelSensing(xCHno, 2);   %% Reset channel status

%     phy_multiChannelSensing(xCHno, 3, waveformPayloadBuffer,
%     entity.data.Address2, obj.getCurrentTime()*1000);  %% buffer DATA to
%     waveformBuff

%     phy_multiChannelSensing(xCHno, 4, waveformPayloadBuffer,
%     entity.data.Address2, obj.getCurrentTime()*1000);  %% set ACK to waveformBuff


%     phy_multiChannelSensing(xCHno, 5);  %% get DATA after interference

%     phy_multiChannelSensing(xCHno, 6)   %% get ACK after interference

%         varargin{3}: record currently transmitting nodes; Due to the design, a
%         node may send several replicas to several channel. A node cannot
%         interfer itself, interference only came from other nodes in the
%         field. varargin{3} is working with persistent txMap to record if the
%         transmission from specific node already exist. If yes, do not add
%         interference, if no add interference to the 'waveformBuff'
%         variable; 

%%
     persistent status waveformBuff txMap colInd
     numberofChannel = 7;
     if isempty(status)
         status = zeros(numberofChannel,1);
     end
     
     if isempty(colInd)
         colInd = zeros(numberofChannel,1);
     end
         
     if isempty(waveformBuff)
        waveformBuff = zeros(numberofChannel,3935);
     end
         
     if isempty(txMap)
         txMap=containers.Map('KeyType','double','ValueType','any');
         for i = 1 : numberofChannel
             txMap(i) = [];
         end
     end
     
     waveformLength=3935; % temporarily comment evalin to accelerate the simulation efficiency
     
    %%
    switch varargin{2}
        case 0 % set channel status            
             status(varargin{1}+1) = varargin{3};
        case 1 % get channel status 
            out = status(varargin{1}+1);
        case 2 % reset channel status
            waveformBuff(varargin{1}+1,1:3935)=0;
            colInd(varargin{1}+1) = 0;
            txMap(varargin{1}+1) = [];                          
        case 3 %3 -- set DATA to waveformBuff     
             % Buff Data  channelSensing(xCHno, 3, waveformPayloadBuffer,entity.data.Address2,obj.getCurrentTime()*1000);                          
             SCHx = txMap(varargin{1}+1);             
             if ~ismember(varargin{4},SCHx)
                 if varargin{nargin}==1
                    disp(['T= ' num2str(varargin{5}) 'ms, <---Channel--->: New Data waveform from node' num2str(varargin{4}) ' received.']);
                 end                 
                 if ~isempty (SCHx)>0 && colInd(varargin{1}+1)==0
                     colInd(varargin{1}+1)=1;
                 end                                                   
                 txMap(varargin{1}+1)=[txMap(varargin{1}+1) varargin{4}];                
                 waveformBuff(varargin{1}+1,1:waveformLength)=waveformBuff(varargin{1}+1, 1:waveformLength)+varargin{3}';                  
             else
                 if varargin{nargin}==1
                    disp(['T= ' num2str(varargin{5}) 'ms, <---Channel--->: Data waveform from node ' num2str(varargin{4})  ' already in channel']);
                 end
             end             
        case 4 % set ACK to waveformBuff
             % Buff ACK    channelSensing(xCHno, 4, waveformPayloadBuffer,entity.data.Address2,obj.getCurrentTime()*1000);   
             %disp('set ACk to waveformBuff');
             SCHx = txMap(varargin{1}+1);
             if ~ismember(varargin{4},SCHx)            
                 if varargin{nargin}==1
                    disp(['T= ' num2str(varargin{5}) 'ms, <---Channel--->: New ACK waveform from node' num2str(varargin{4}) ' received,']);
                 end
                 txMap(varargin{1}+1)=[txMap(varargin{1}+1) varargin{4}];
                 waveformBuff(varargin{1}+1, 1:975)=waveformBuff(varargin{1}+1, 1:975)+varargin{3}';  
             else 
                 if varargin{nargin}==1
                     disp(['T= ' num2str(varargin{5}) 'ms, <---Channel--->: ACK waveform from node ' num2str(varargin{4})  ' already in channel.']);
                 end
            end             
        case 5 % get DATA after interference            
             out=waveformBuff(varargin{1}+1, 1:waveformLength)';                  
             temp = txMap(varargin{1}+1);
             temp = temp(temp~=varargin{4});                          
             txMap(varargin{1}+1) = temp;             
             if colInd(varargin{1}+1)~=0
                 fcn_carGlobalDB('collision',varargin{5});
                 colInd(varargin{1}+1)=0;
             end         
        case 6 % get ACK after interference            
            out=waveformBuff(varargin{1}+1, 1:975)';            
            temp = txMap(varargin{1}+1);
            temp = temp(temp~=varargin{4});            
            txMap(varargin{1}+1)=temp;                                         
        case 'clearmem'
            %disp('clearmem');
             clearvars status waveformBuff txMap colInd;
        otherwise
             %disp('Wrong varargin{1}s for phy_ChannelSensing!');             
     end                          
end

