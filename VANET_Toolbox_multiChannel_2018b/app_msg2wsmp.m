function wsmp = app_msg2wsmp(msg,wsmp,pos )
% wsmp = msg2wsmp(msg,wsmp,pos )
% 16 bits for one decimal
% decNum is the number you want to put into wsmp
% pos is the position for the msg in WSMP
% pos==1, 1:16 bits; pos==2, 17:32 bits.
    coder.extrinsic('str2double');
    
    msg_bin=reshape(dec2bin(typecast(msg,'uint32'),32).',1,[]);

    msg_bin=msg_bin(33:64);

    
%     msg=round(msg);
%     msg_bin=dec2bin(msg,16);
    for i=1:numel(msg_bin)  
        wsmp(i+32*(pos-1))=str2double(msg_bin(i));
    end
end

