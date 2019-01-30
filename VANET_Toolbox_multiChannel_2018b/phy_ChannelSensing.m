function out = phy_ChannelSensing( varargin)
    % varargin{1} 
%         0 -- set channel status
%         1 -- get channel status
%         2 -- reset waveformBuff 
%         3 -- set DATA to waveformBuff
%         4 -- set ACK to waveformBuff
%         5 -- get DATA after interference
%         6 -- get ACK after interference

%         varargin{2}:  0 -- channel free 1 -- channel busy
%         varargin{3}: record currently transmitting nodes; Due to the design, a
%         node may send several replicas to several channel. A node cannot
%         interfer itself, interference only came from other nodes in the
%         field. varargin{3} is working with persistent txMap to record if the
%         transmission from specific node already exist. If yes, do not add
%         interference, if no add interference to the 'waveformBuff'
%         variable; 

     persistent status waveformBuff txMap colInd
%      txtEnable=evalin('base','txtEnable');
     
     if isempty(status) || isempty(colInd)
         status=0;         
         colInd=0;
     end
     
     if isempty(waveformBuff)
         waveformBuff=zeros(3935,1);         
     end

     if isempty(txMap)
         txMap=[];
     end
     
%      waveformLength=evalin('base','waveformLength');     
     waveformLength=3935; % temporarily comment evalin to accelerate the simulation efficiency
     switch varargin{1}
         case 0 %0 -- set channel status
             status=varargin{2};
         case 1 %1 -- get channel status
             out=status;
         case 2 %2 -- reset waveformBuff 
             waveformBuff=ones(3935,1);
             txMap=[];
             colInd=0;
         case 3 %3 -- set DATA to waveformBuff     
             % Buff Data  channelSensing(3,waveformPayloadBuffer,entity.data.Address2,obj.getCurrentTime()*1000);
             if ~ismember(varargin{3},txMap)
                 if varargin{nargin}==1
                    disp(['T= ' num2str(varargin{4}) 'ms, <---Channel--->: New Data waveform from node' num2str(varargin{3}) ' received.']);
                 end
                 
                 if ~isempty (txMap)>0 && colInd==0
                     colInd=1;
                 end
                 txMap=[txMap varargin{3}];
                 waveformBuff(1:waveformLength)=waveformBuff(1:waveformLength).*varargin{2};         
             else
                 if varargin{nargin}==1
                    disp(['T= ' num2str(varargin{4}) 'ms, <---Channel--->: Data waveform from node ' num2str(varargin{3})  ' already in channel']);
                 end
             end
% 
         case 4 %4 -- set ACK to waveformBuff  
             % Buff ACK    channelSensing(4,waveformPayloadBuffer,entity.data.Address2,obj.getCurrentTime()*1000);             
             if ~ismember(varargin{3},txMap)
                 if varargin{nargin}==1
                    disp(['T= ' num2str(varargin{4}) 'ms, <---Channel--->: New ACK waveform from node' num2str(varargin{3}) ' received,']);
                 end
                 txMap=[txMap varargin{3}];
                 waveformBuff(1:975)=waveformBuff(1:975).*varargin{2};  
             else 
                 if varargin{nargin}==1
                     disp(['T= ' num2str(varargin{4}) 'ms, <---Channel--->: ACK waveform from node ' num2str(varargin{3})  ' already in channel.']);
                 end
             end
             
         case 5  %5 -- get DATA after interference                               % Get Data             
             out=waveformBuff(1:waveformLength);   
             txMap=txMap(txMap~=varargin{3});
             
             if colInd~=0
                 fcn_carGlobalDB('collision',varargin{4});
                 colInd=0;
             end
         case 6  %6 -- get ACK after interference
             % Get ACK
             out=waveformBuff(1:975);
             txMap=txMap(txMap~=varargin{3});
         case 'clearmem'
             clearvars status waveformBuff txMap colInd;
         otherwise
             disp('Wrong varargin{1}s for phy_ChannelSensing!');             
     end                  
             
end

