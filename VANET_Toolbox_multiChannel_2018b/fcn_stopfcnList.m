function fcn_stopfcnList(varargin)
    tocValue=toc;
    FileName=['results/simTime-',num2str(varargin{1}),'-',datestr(now, 'yyyymmddHHMM'),'-','.mat'];
    save(FileName,'tocValue'); 

    str1=strcat(num2str(varargin{1}),' Cars-2lanes1direction');    
    fcn_carGlobalDB('save',str1);       
    fcn_carGlobalDB('clearmem');    
    fcn_CAVrecord('log',num2str(varargin{1}));    
    
    fcn_carLocalDB('clearmem');
    fcn_initInfo('clearmem');    
    fcn_eventsCount('clear',varargin{1},varargin{2});    
    phy_ChannelSensing('clearmem');
end