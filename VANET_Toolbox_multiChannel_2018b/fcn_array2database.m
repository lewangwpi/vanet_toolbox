function outDatabase=fcn_array2database(varargin)
    % nargin=2 --> counter database, save the counter times of each index
        % in1-inDatabase
        % in2-key
    % nargin=3 --> save key,value pair
        % in1-inDatabase
        % in2-key
        % in3-value
    inArray=varargin{1};
    [checkExist,pos]=ismember(varargin{2},inArray);
    
    if ~checkExist
%         disp('not exist');
        indexCol=inArray(:,1);
        indexCol=indexCol(indexCol~=0);
        
        pos=length(indexCol)+1;
        inArray(pos)=varargin{2};
        if nargin>2
            inArray(pos,2)=varargin{3};
        else
            inArray(pos,2)=inArray(pos,2)+1;
        end
        
    else
%         disp('exist');
        rowData=inArray(pos,:);
        if nargin>2
            inArray(pos,length(rowData(rowData~=0))+1)=varargin{3};
        else
            inArray(pos,2)=inArray(pos,2)+1;
        end
        
    end
    outDatabase=inArray;
end