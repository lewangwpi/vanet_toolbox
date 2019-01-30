function plotMAP(road)
    global p
    global p_color
    global clk
    global NS WE
    switch road
        case 'highway'
            figure(2);
            eml.extrinsic('imread');
            img = imread('figs/highway.png','png');
            min_x = -415;
            max_x = 415;
            min_y = -415;
            max_y = 415;
            eml.extrinsic('imagesc');
            imagesc([min_x max_x], [min_y max_y], flipdim(img, 1));
            set(gca,'ydir','normal');
            axis off
            hold on

            % Display clock text
            clk = text(250, 392, '', 'FontSize', 8);

% %             % Display number of vehicles:
% %             noCar=evalin('base','numStations');
% %             text(250,350,['Vehicle #:  ' num2str(noCar)], 'FontSize', 8);

            y = zeros(100, 100) + 1000; %100: number of CAVs 

            p = plot(y,'o','MarkerSize',8);
            p_color = zeros(1, 100); % check if a CAV has determined its color
        case 'crossRD'
            figure(2);
            eml.extrinsic('imread');    
            img=imread('figs/crossing.jpg','jpg');
            z=100;
            min_x = -z;
            max_x = z;
            min_y = -z;
            max_y = z;
            eml.extrinsic('imagesc');
            imagesc([min_x max_x], [min_y max_y], flipdim(img, 1));
            set(gca,'ydir','normal');
            axis off
            hold on

            % Display clock text
            clk = text(50, 92, '', 'FontSize', 8);

            % Display number of vehicles:
            noCar=evalin('base','numStations');
            text(50,150,['Vehicle #:  ' num2str(noCar)], 'FontSize', 8);

            y = zeros(100, 100) + 1000; %100: number of CAVs 

            p = plot(y,'o','MarkerSize',3);
            p_color = zeros(1, 100); % check if a CAV has determined its color

            WE=plot([-2,2],[0,0],'o','MarkerSize',4);
            NS=plot([0,0],[-3,3],'o','MarkerSize',4);
            WE.MarkerEdgeColor='green';
            WE.MarkerFaceColor='green';
            NS.MarkerEdgeColor='red';
            NS.MarkerFaceColor='red';
    end
end