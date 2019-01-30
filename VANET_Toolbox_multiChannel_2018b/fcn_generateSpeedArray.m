function [outputSpeedArray] = fcn_generateSpeedArray(nCars,meanSpeed,stddevSpeed)
    %fcn_generateSpeedArray Create the 
    %   Detailed explanation goes here
    % randn 
    % Normally distributed random numbers
    rng('shuffle');

    outputSpeedArray = stddevSpeed .* randn(nCars,1) + meanSpeed;
end

