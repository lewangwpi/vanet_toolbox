function [x,y]=fcn_addrConv(posX,posY,lane,mapBorder)
    switch lane
        case 1
            x=posX;
            y=posY;
        case 2
            x=mapBorder-posX;
            y=posY;
        otherwise
            x=200/2+posY-6;
            sym=(lane-4)*2+1;
            y=sym*(posX-100+sym*6);
%         case 3
%             x=200/2-2+(posY-4);
%             y=106-posX;
%         case 4
%             x=200/2+2+(posY-8);
%             y=-96+posX;
    end
          

end