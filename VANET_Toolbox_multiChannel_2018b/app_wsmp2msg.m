function msg = app_wsmp2msg(wsmp,pos )
% 16 bit for one decimal
% pos is the position for the msg in WSMP
% pos==1, 1:16 bits; pos==2, 17:32 bits.
%     coder.extrinsic('num2str');    
%     strmsg=num2str(wsmp(1+32*(pos-1):32*pos));
%     msg=bin2dec(strmsg);
    empmsg=zeros(1,32);
    rcvmsg=wsmp(1+32*(pos-1):32*pos);
    for i=1:numel(rcvmsg)
%         empmsg(i)=num2str(rcvmsg(i));
        empmsg(i)=int2str(rcvmsg(i));
    end
    
    paddings=dec2bin(0,32);
    msg=[paddings,empmsg];
    msg=typecast(uint32(bin2dec(reshape(msg,32,[]).')),'double');
end

