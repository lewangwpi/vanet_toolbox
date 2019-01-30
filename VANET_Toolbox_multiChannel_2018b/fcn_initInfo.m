function varargout=fcn_initInfo(varargin)
    persistent lane1 lane2 lane3 lane4
    
    switch varargin{1}
        case 'init'
%             disp('initInfo initiated');
            lane1=zeros(100,10);
            lane2=zeros(100,10);
            lane3=zeros(100,10);
            lane4=zeros(100,10);
                        
        case 'clearmem'
            clearvars lane1 lane2 lane3 lane4;
        case 'set' % initInfo('set',obj.vehicleID,obj.curPositionX,obj.curPositionY,obj.lane,obj.curSpeedX,obj.acceleration);                            
            switch varargin{5}
                case 1                    
                    for i=1:nargin-1
                        lane1(varargin{2},i)=varargin{i+1};                                                
                    end                            
                case 2
                    for i=1:nargin-1
                        lane2(varargin{2},i)=varargin{i+1};                        
                    end                    
                case 3
                    for i=1:nargin-1
                        lane3(varargin{2},i)=varargin{i+1};                        
                    end
                case 4
                    for i=1:nargin-1
                        lane4(varargin{2},i)=varargin{i+1};                        
                    end
            end
        case 'get'
            switch varargin{2}
                case 1
                    varargout{1}=lane1;     
%                     lane1(1:4,:)
                case 2
                    varargout{1}=lane2;
                case 3
                    varargout{1}=lane3;
                case 4
                    varargout{1}=lane4;
            end
    end

end