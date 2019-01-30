function [SNR] = phy_pathlost(distance)
    %PHY_PATHLOST Summary of this function goes here
    %   Detailed explanation goes here

    cbw = 'CBW10';
    % Create a format configuration object for a SISO nonHT transmission
    cfgnonHT = wlanNonHTConfig();
    cfgnonHT.NumTransmitAntennas = 1;    % 1 transmit antennas
    cfgnonHT.ChannelBandwidth = cbw;
    fs = wlanSampleRate(cfgnonHT);
    fc = 5855e6;
    c = 299792458;
    txHeight = 1.5;
    rxHeight =  1.5;
    PowT = 30; 


    [Etot,PrEfield,reflCoeff] = phy_twoRay(distance,txHeight,rxHeight,c/fc,PowT,1,1,0);
    % Noise 
    % Thermal noise -174 dbm
    % 10Mhz band 70 dbm
    %Noise figure worst cas is 15 db
    noise = -89;
    SNR = PrEfield - noise;
end

