function fcn_eventsCount(varargin)
    persistent eventscount
            
        switch varargin{1}
            case 'init'
                eventscount=zeros(4,10);
            case 'clear'                                
                FileName=['results/eventscount-',num2str(varargin{2}), 'cars-' , num2str(varargin{3}) , 'seconds-',datestr(now, 'yyyymmddHHMM'),'-','.mat'];
                save(FileName,'eventscount');                   
                clearvars eventscount;
            case 'app'
                eventscount(1,1)=eventscount(1,1)+1;
            case 'mac'
                eventscount(2,1)=eventscount(2,1)+1;
            case 'phy'
                eventscount(3,1)=eventscount(3,1)+1;                            
        end        
    
end