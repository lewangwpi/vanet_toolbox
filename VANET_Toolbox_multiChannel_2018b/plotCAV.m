function plotCAV(varargin)

    % plotCAV(vehicleID,lane,posX,posY,time,road)


    global p
    global p_color
    global clk

     % display time
    tStr = sprintf('%.1f',varargin{5});
    set(clk,'String',['Sim Time: ' tStr 's']);
    
    switch varargin{6}
        case 'crossRD'
            roadLength=evalin('base','roadLength');
            scale=roadLength/200;
            switch varargin{2} % switch lane
                case 1        
                    if p_color(varargin{1}) == 0            
                        if mod(varargin{1},2)==0
                            p(varargin{1}).MarkerEdgeColor = 'yellow';
                            p(varargin{1}).MarkerFaceColor = 'yellow';
                            p_color(varargin{1}) = 1;                
                        else        
                            p(varargin{1}).MarkerEdgeColor = 'red';
                            p(varargin{1}).MarkerFaceColor = 'red';
                            p_color(varargin{1}) = 1;                                
                        end             
                    end

                    p(varargin{1}).XData = varargin{3}/scale-100;
                    p(varargin{1}).YData = varargin{4}-6;        


                case 2        
                    if p_color(varargin{1}) == 0
                        if mod(varargin{1},2)==0
                            p(varargin{1}).MarkerEdgeColor = 'blue';
                            p(varargin{1}).MarkerFaceColor= 'blue';
                            p_color(varargin{1}) = 1;
                        else
                            p(varargin{1}).MarkerEdgeColor = 'green';
                            p(varargin{1}).MarkerFaceColor= 'green';
                            p_color(varargin{1}) = 1;
                        end
                    end
                    p(varargin{1}).XData = - varargin{3}/scale+100;
                    p(varargin{1}).YData = varargin{4}-6 ;                

                case 3
                    if p_color(varargin{1}) == 0
                        p(varargin{1}).MarkerEdgeColor = 'red';
                        p(varargin{1}).MarkerFaceColor = 'red';
                        p_color(varargin{1}) = 1;
                    end
                    p(varargin{1}).XData = varargin{4}-6;
                    p(varargin{1}).YData = - varargin{3}/scale+100;

                case 4
                    if p_color(varargin{1}) == 0
                        p(varargin{1}).MarkerEdgeColor = 'green';
                        p(varargin{1}).MarkerFaceColor = 'green';
                        p_color(varargin{1}) = 1;
                    end
                    p(varargin{1}).XData = varargin{4}-5.5;
                    p(varargin{1}).YData = varargin{3}/scale-100;

            end
        case 'highway'
%             roadLength=840;
            roadLength=evalin('base','roadLength');
            scale=roadLength/840;
            switch varargin{2}
                case 1        
                    if p_color(varargin{1}) == 0

                        if mod(varargin{1},2)==0
                            p(varargin{1}).MarkerEdgeColor = 'yellow';
                            p(varargin{1}).MarkerFaceColor = 'yellow';
                            p_color(varargin{1}) = 1;                
                        else        
                            p(varargin{1}).MarkerEdgeColor = 'red';
                            p(varargin{1}).MarkerFaceColor = 'red';
                            p_color(varargin{1}) = 1;                                
                        end             
                    end

                    p(varargin{1}).XData = varargin{3}/scale - 415;
                    p(varargin{1}).YData = varargin{4}/4*75 - 85;        


                case 2        
                    if p_color(varargin{1}) == 0
                        if mod(varargin{1},2)==0
                            p(varargin{1}).MarkerEdgeColor = 'blue';
                            p(varargin{1}).MarkerFaceColor= 'blue';
                            p_color(varargin{1}) = 1;
                        else
                            p(varargin{1}).MarkerEdgeColor = 'green';
                            p(varargin{1}).MarkerFaceColor= 'green';
                            p_color(varargin{1}) = 1;
                        end
                    end
                    p(varargin{1}).XData = - varargin{3}/scale + 415;
                    p(varargin{1}).YData = varargin{4}/4*75 - 85;                

            end            
    end        
end