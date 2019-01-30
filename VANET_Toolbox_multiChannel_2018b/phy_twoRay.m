function [Etot,PrEfield,reflCoeff] = phy_twoRay(dist,txHeight,rxHeight,lambda,Pt,Gt,Gr,polarization)
    % TWORAY Calculates the two ray path loss model. 
    % For details, see T. S. Rappaport, "Wireless Communications: Principles
    % and Practice." Prentice Hall, 1996.)
    %
    % Input:
    %	dist                    distance between Tx and Rx
    %   txHeight:               Tx height
    %   rxHeight:               Rx height
    %   lambda:                 wavelenght in meters
    %   Pt                      transmitting power in dBm
    %   Gt, Gr                  antenna gains in dBi
    %   polarization            polarization (0 - vertical; 1 - horizontal)
    % Output:
    %   
    %
    % Copyright (c) 2014-2015, Mate Boban

    % Empirically established relative permittivity which gives the best-fit
    % reflection coefficients (see paper for details). 
    er = 1.003;
    % Distance traveled by ground-reflected ray
    dRefl = sqrt(dist.^2 + (txHeight+rxHeight).^2);
    % Sine and cosine of incident angle
    sinTheta = (txHeight+rxHeight)./dRefl;
    cosTheta = dist./dRefl;

    if polarization==0
        % Vertical antenna polarization
        reflCoeff = (-er.*sinTheta+sqrt(er-cosTheta.^2))./...
            (er.*sinTheta+sqrt(er-cosTheta.^2));    
    elseif polarization ==1
        % Horizontal antenna polarization
        reflCoeff = (sinTheta-sqrt(er-cosTheta.^2))./...
            (sinTheta+sqrt(er-cosTheta.^2));
    else
        error('Unknown antenna polarization');
    end

    Pt = 10.^(Pt./10)./1000; 

    % %eference distance in meters (purposely hard-coded)
    d0 = 1; 
    % Convert gains from dB 
    Gt = 10^(Gt/10); 
    Gr = 10^(Gr/10);
    % Reference power flux density at distance d0
    Pd0 = Pt*Gt/(4*pi*d0^2);
    % Reference E-field
    E0 = sqrt(Pd0*120*pi); 
    % LOS distance
    d1 = sqrt((txHeight-rxHeight).^2+dist.^2); 
    % Ground-reflected distance
    d2 = sqrt((txHeight+rxHeight).^2+dist.^2); 
    % Speed of light
    c = 299792458; 
    % Frequency
    freq=c/lambda;
    % Carrier frequency (radians per second)
    freqAng = 2*pi*freq; 
    % E-field (in V/m)
    Etot = E0*d0./d1.*cos(freqAng.*(d1./c-d1./c)) + reflCoeff.*E0*d0./d2.*cos(freqAng.*(d1./c-d2./c));
    % Received power (in W)
    Prec = Etot.^2.*Gr*lambda^2/(480*pi^2); 
    % Received power (in dBm)
    PrEfield = 10*log10(Prec)+30; 
end

