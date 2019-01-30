function plotLight(tag)

    global WE NS    
    switch tag
        case 'weGREEN'
            WE.MarkerEdgeColor='green';
            WE.MarkerFaceColor='green';
        case 'weYELLOW'
            WE.MarkerEdgeColor='yellow';
            WE.MarkerFaceColor='yellow';
        case 'weRED'
            WE.MarkerEdgeColor='red';
            WE.MarkerFaceColor='red';
        case 'nsGREEN'
            NS.MarkerEdgeColor='green';
            NS.MarkerFaceColor='green';
        case 'nsYELLOW'
            NS.MarkerEdgeColor='yellow';
            NS.MarkerFaceColor='yellow';
        case 'nsRED'
            NS.MarkerEdgeColor='red';
            NS.MarkerFaceColor='red';
    end
end

