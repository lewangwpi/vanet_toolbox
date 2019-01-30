classdef macFrame < handle
    %macFrame Mac frame
    %   Object to represent all the files in a mac frame.
    
    properties (Constant)
        % the protocol version is zero based on the standard 802.11-2012
        protocolVersionField = [0 0];
        MANAGEMENTTYPE = uint8(0);
        CONTROLTYPE = uint8(1);
        DATATYPE = uint8(2);
        ACKSUBTYPE =  uint8(13) % binary 1101
        CTSSUBTYPE = uint8(12) % binary 1100
        
        % QOS subtypes used for QoS field
        QOSDATA  = uint8(8) %binary 1000
        QOSDATAACK = uint8(9) %binary 1001
        QOSDATAPOLL = uint8(10) %binary 1010
        QOSDATAACKPOLL = uint8(11) % binary 1011
        QOSNULL = uint8(12) % binary 1100
        
        %ACK policies
        % Normal Ack or Implicit Block Ack Request '00'
        NORMALACK = uint8(0) ; % '00'
        NOACK = uint8(2) ; %'10'
        %No Explicit Acknowledgement or Scheduled Ack under PSMP
        NOEXACK = uint8(1); %'01'
        %Block Acknowledgement
        BLKACK = uint8(3); % '11'
        
    end
    properties
        %Fields inside the Frame Control field
        
        typeField;
        subtypeField;
        toDSField;
        fromDSField;
        moreFragField;
        retryField;
        pwrMgtField;
        moreDataField;
        protectedFrameField;
        orderFrameField;
        
        % the Duration ID can be used for Duration or ID Field
        % based on the value
        durantionIDField
        
        % Address 1 contains the receive address (RA) and is present in all
        % frames. Address 2 contains the transmit address (TA) and is present in all frames except
        % ACK and CTS.
        address1Field;
        address2Field;
        % Address 3 is present in data and management frames. In a data frame, the address
        % carried by the Address 3 field is dependent on the To DS and From DS bit settings
        
        address3Field;
        address4Field;
        
        fragmentNumberField;
        sequenceNumberField;
        
        %        The Traffic Identifier (TID) subfield identifies the TC or TS to which the corresponding
        %           MSDU or MSDU fragment in the frame body belongs. The TID subfield also
        %           identifies the TC or TS for which a TXOP is being requested through the setting of the
        %            TXOP Duration Requested or Queue Size subfields.
        TIDField
        ESOPField
        ACKPolicy
        AMSDUPresent
        APPSbufferState
        TXOPlimit
        TXOPduration
        queueSize
        isAP
        %data need to enconde already in array of bits
%         data = [];
        data=zeros(1,1);
        fcsGen
        fcsDet                                
    end
    properties (Dependent)
        %Frame Control field is dependet of many subparameters
        frameControlField
        %The Sequence Control field consists of a 4-bit Fragment Number
        %and a 12-bit Sequence Number
        sequenceControlField % Sequence Control field
        frameArray
        idField
        durantionField
        QOScontrolField;
        
    end
    
    % Mthods for attibutes
    
    methods
        function obj = macFrame()
            
            %create default values for the fields
            %considering it is a ACK package
            
            % Management type
            obj.typeField = obj.CONTROLTYPE;
            % Subtype ACK 1101
            obj.subtypeField = obj.ACKSUBTYPE;
            % to and from DS are 0 for management frame
            obj.toDSField = 0;
            obj.fromDSField = 0;
            %It is set to 0 in MPDUs that contain a complete MSDU
            obj.moreFragField = 0;
            %The Retry field is set to 1 in any data or management frame that is a retransmission of an
            %earlier frame. It is set to 0 in all other frames. A receiving station uses this indication to aid
            %in eliminating duplicate frames.
            obj.retryField = 0 ;
            %A value of 0 indicates that the station will be in active
            %mode, while a value of 1 indicates that the station will be in Power Save (PS) mode. This
            %field is always set to 0 by the AP.
            obj.pwrMgtField = 0 ;
            
            obj.moreDataField = 0;
            %The Protected Frame field, when set to 1, indicates that the Frame Body field has been
            %encrypted.
            obj.protectedFrameField = 0;
            %As may be appreciated, this field was never widely used. It is reused in 802.11n to
            %indicate the presence of HT Control field in QoS Data frames. Prior to 802.11n, this bit
            %was reserved in QoS Data frames, which always had it set to 0.
            obj.orderFrameField = 0;
            
            obj.durantionIDField =  49153;
            obj.address1Field = 0 ;
            obj.address2Field = 0;
            
            obj.address3Field = 0 ;
            obj.address4Field = 0 ;
            
            obj.fragmentNumberField = 0 ;
            obj.sequenceNumberField = 0 ;
            
            % QOS is optional, it just to create the variables
            obj.TIDField = 0;
            obj.ESOPField = 0;
            obj.ACKPolicy = 0;
            obj.AMSDUPresent = 0;
            obj.APPSbufferState = 0;
            obj.TXOPlimit = 0;
            obj.TXOPduration = 0;
            obj.queueSize = 0;
            obj.isAP = 0;
            %create the CRC generator and decoder
            
            obj.fcsGen = comm.CRCGenerator('z^32 + z^26 + z^23 + z^22 + z^16 + z^12 + z^11 + z^10 + z^8 + z^7 + z^5 + z^4 + z^2 + z + 1');
            obj.fcsDet = comm.CRCDetector('z^32 + z^26 + z^23 + z^22 + z^16 + z^12 + z^11 + z^10 + z^8 + z^7 + z^5 + z^4 + z^2 + z + 1');
            
            
        end
        function value = get.idField(obj)
            %             If the two high order bits are set in a PS-Poll frame then the low
            %               order 14 bits are interpreted as the association identifier (AID).
            %               Binary 1100000000000000 Decimal 49152
            if obj.durantionIDField >= 49152
                value = obj.durantionIDField - 49152;
            else
                value = 0 ;
            end
            
            
        end
        function value = get.durantionField(obj)
            %           When the value of the Duration/ID field is less than 32 768 (high order bit not set), then
            %           the value is interpreted as a duration in microseconds and used to update the network
            %           allocation vector (NAV).
            if obj.durantionIDField < 32768
                value =   obj.durantionIDField;
            else
                value = 0 ;
            end
            
            
        end
        function value = get.frameControlField(obj)
            %             value = strcat(obj.protocolVersionField,obj.typeField,obj.subtypeField,...
            %                 obj.toDSField,obj.fromDSField,obj.moreFragField,obj.retryField,...
            %                 obj.pwrMgtField,obj.moreDataField,obj.protectedFrameField,obj.orderFrameField);
            value = obj.protocolVersionField ;
            value = [ value de2bi(obj.typeField,2,'left-msb')];
            value = [ value de2bi(obj.subtypeField,4,'left-msb')];
            value = [ value de2bi(obj.toDSField,1,'left-msb')];
            value = [ value de2bi(obj.fromDSField,1,'left-msb')];
            value = [ value de2bi(obj.moreFragField,1,'left-msb')];
            value = [ value de2bi(obj.retryField,1,'left-msb')];
            value = [ value de2bi(obj.pwrMgtField,1,'left-msb')];
            value = [ value de2bi(obj.moreDataField,1,'left-msb')];
            value = [ value de2bi(obj.protectedFrameField,1,'left-msb')];
            value = [ value de2bi(obj.orderFrameField,1,'left-msb')];
            
            
        end
        function status = decodeframeControlField(obj,inputarray)
            %             value = strcat(obj.protocolVersionField,obj.typeField,obj.subtypeField,...
            %                 obj.toDSField,obj.fromDSField,obj.moreFragField,obj.retryField,...
            %                 obj.pwrMgtField,obj.moreDataField,obj.protectedFrameField,obj.orderFrameField);
            % decode the frame control field
            % the array nust be a 16 positon array
            if numel(inputarray) ~= 16
                status = 0 ;
                return ;
            end
            % the protocol version is read only 
            obj.typeField = bi2de(inputarray(3:4),'left-msb');
            obj.subtypeField = bi2de(inputarray(5:8),'left-msb');
            obj.toDSField = bi2de(inputarray(9),'left-msb');
            obj.fromDSField = bi2de(inputarray(10),'left-msb');
            obj.moreFragField = bi2de(inputarray(11),'left-msb');
            obj.retryField = bi2de(inputarray(12),'left-msb');
            obj.pwrMgtField = bi2de(inputarray(13),'left-msb');
            obj.moreDataField = bi2de(inputarray(14),'left-msb');
            obj.protectedFrameField = bi2de(inputarray(15),'left-msb');
            obj.orderFrameField = bi2de(inputarray(16),'left-msb');
            status = 1;
            return
            
            
        end
        function value = get.QOScontrolField(obj)
            tempb0b3 = 0;
            tempb4 = 0;
            tempb5b6 = 0;
            tempb7 = 0;
            tempb8b15 = 0;
            
            if obj.typeField == obj.DATATYPE
                if obj.isAP
                    if obj.subtypeField == obj.QOSDATAPOLL
                        tempb0b3 = obj.TIDField;
                        tempb4 = obj.ESOPField;
                        tempb5b6 = double(obj.ACKPolicy);
                        tempb7 = obj.AMSDUPresent;
                        tempb8b15 = obj.TXOPlimit;
                    elseif obj.subtypeField == obj.QOSDATA || obj.subtypeField == obj.QOSDATAACK || obj.subtypeField == obj.QOSNULL
                        tempb4 = obj.ESOPField;
                        tempb8b15 = obj.APPSbufferState;
                    end
                elseif obj.subtypeField == obj.QOSDATA
                    % dependes of the value of bit 4 if Zero use the TXOP Duration Requested
                    % if bit 4 is not zero, use Queue Size
                    tempb8b15 = obj.TXOPduration;
                end
                
                value = [ de2bi(tempb0b3,4,'left-msb')];
                value = [ value de2bi(tempb4,1,'left-msb')];
                value = [ value de2bi(tempb5b6,2,'left-msb')];
                value = [ value de2bi(tempb7,1,'left-msb')];
                value = [ value de2bi(tempb8b15,8,'left-msb')];                                                
            else
                value=0;
            end
        end
        function status = decodeQOScontrolField(obj,inputarray)
            if numel(inputarray) ~= 16
                status = 0 ;
                return ;
            else
                status = 1;
            end
            if obj.typeField == obj.DATATYPE
                if obj.isAP
                    if obj.subtypeField == obj.QOSDATAPOLL
                        obj.TIDField = bi2de(inputarray(1:4),'left-msb');
                        obj.ESOPField = bi2de(inputarray(5),'left-msb');
                        obj.ACKPolicy = bi2de(inputarray(6:7),'left-msb');
                        obj.AMSDUPresent = bi2de(inputarray(8),'left-msb');
                        obj.TXOPlimit = bi2de(inputarray(9:16),'left-msb');
                    elseif obj.subtypeField == obj.QOSDATA || obj.subtypeField == obj.QOSDATAACK || obj.subtypeField == obj.QOSNULL
                        obj.ESOPField = bi2de(inputarray(5),'left-msb');
                        obj.APPSbufferState = bi2de(inputarray(9:16),'left-msb');
                    end
                elseif obj.subtypeField == obj.QOSDATA
                    % dependes of the value of bit 4 if Zero use the TXOP Duration Requested
                    % if bit 4 is not zero, use Queue Size
                    obj.TXOPduration= bi2de(inputarray(9:16),'left-msb');
                end
            end
        end
        function value = get.sequenceControlField(obj)
            
            
            value = [ de2bi(obj.fragmentNumberField,4,'left-msb') de2bi(obj.sequenceNumberField,12,'left-msb')];
            
            
        end
        function status = decodeSequenceControlField(obj,inputarray)
            
            if numel(inputarray) ~= 16
                status = 0 ;
                return ;
            end
            obj.fragmentNumberField = bi2de(inputarray(1:4),'left-msb');
            obj.sequenceNumberField = bi2de(inputarray(5:16),'left-msb');
            status = 1;
            
            
        end
        function set.data(obj,value)
            
            if iscolumn(value)
                newvalue = value.';                
                nbits = numel(newvalue);                
                rest = rem(nbits,8);
                if(rest > 0)
                   finalvalue = [newvalue zeros(1,(8-rest))]; 
                   obj.data=finalvalue;
                else
                    obj.data=double(newvalue);
                end    
            else                
                nbits = numel(value);    
                rest=rem(nbits,8);
                if(rest > 0)
                   final1value = [value zeros(1,(8-rest))]; 
                   obj.data=final1value;
                else
                    obj.data=double(value);
                end    
            end                
            obj.data=reshape(obj.data,[1,numel(obj.data)]);                        
            
        end
        function set.typeField(obj,value)
            if isnumeric(value)
                obj.typeField = uint8(value);
            elseif ischar(value)
                lowerValue = lower(value);
                switch lowerValue
                    
                    case {'00','management'}
                        obj.typeField = obj.MANAGEMENTTYPE;
                    case {'01', 'control'}
                        obj.typeField = obj.CONTROLTYPE;
                    case {'10', 'data'}
                        obj.typeField = obj.DATATYPE;
                end
            else
                msg = 'Wrong format of type field';
                error(msg);
            end
            
        end
        function set.subtypeField(obj,value)
            if isnumeric(value)
                obj.subtypeField = uint8(value);
            else
                msg = 'Wrong format of subtype field';
                error(msg);
            end
            
        end
        function set.ACKPolicy(obj,value)
            if isnumeric(value)
                obj.ACKPolicy = uint8(value);
            elseif ischar(value)
                
                lowerValue = lower(value);
                switch lowerValue
                    
                    case {'00','normal'}
                        obj.ACKPolicy = obj.NORMALACK;
                    case {'10', 'no'}
                        obj.ACKPolicy = obj.NOACK;
                    case {'01', 'noex'}
                        obj.ACKPolicy = obj.NOEXACK;
                    case {'11', 'block'}
                        obj.ACKPolicy = obj.BLKACK;
                end
            else
                msg = 'Wrong format of ack policy';
                error(msg);
            end
            
        end
        function value = get.frameArray(obj)
            % for data we combine the data and header in a n*1 binary array
            % the ack is only a header.
            value = [ obj.frameControlField de2bi(obj.durantionIDField,16,'left-msb')];
            value = [ value  de2bi(obj.address1Field,48,'left-msb')];
            if  (obj.typeField ~= obj.CONTROLTYPE)  || (obj.subtypeField ~= obj.ACKSUBTYPE && obj.subtypeField ~= obj.CTSSUBTYPE)
                value = [ value  de2bi(obj.address2Field,48,'left-msb')];
            else
                
            end
            if  (obj.typeField == obj.MANAGEMENTTYPE || obj.typeField == obj.DATATYPE)
                value = [ value  de2bi(obj.address3Field,48,'left-msb')];
            end
            value = [ value  obj.sequenceControlField];
            if (obj.toDSField == 1 && obj.fromDSField == 1)
                value = [ value  de2bi(obj.address4Field,48,'left-msb')];
            end
            if( obj.typeField == obj.DATATYPE && obj.subtypeField >= obj.QOSDATA && obj.subtypeField <= obj.QOSNULL)
                value = [ value  obj.QOScontrolField];
            end
            
            
            % There is a extra optional filed HT Control that will not
            % be implement because 802.11p dont use it.            
            if ~isempty(obj.data)
%                 datareshape=reshape(obj.data,[1,numel(obj.data)]);                
                tempData=zeros(1,numel(obj.data));
                for i=1:numel(obj.data)
                    tempData(1,i)=obj.data(i);
                end
%                 value = [ value  obj.data];
                value=[value tempData];
            end
            
            
            %conversion of the value to run over the CRC 32 lib without
            %problem
            valueTransLogical =  logical(value.');
            value = step(obj.fcsGen,valueTransLogical);
        end
        
        function [status , msg] = decodeArray(obj,inputarray)
            status = 0;
            currentindex = 1;
            obj.fcsGen.reset();
            obj.fcsDet.reset();
            [ lin, col ] = size(inputarray);
            if lin>col
                rxArray=zeros(lin,col);
                rxArray=inputarray;
            else %col>lin                
                rxArray=zeros(col,lin);
                rxArray=inputarray.';
            end
            
%             if (col > lin)                
%                 inputarray = inputarray.';
%             end
                
%             [verfArray, errors] = step(obj.fcsDet,inputarray);
            [verfArray, errors] = step(obj.fcsDet,rxArray);
            verfArray = verfArray.';
            sizeInput = numel(verfArray);
            if errors == 0
                % The crc verify correcty
                status = obj.decodeframeControlField(verfArray(currentindex:currentindex+15));
                if status
                    currentindex = currentindex+16;
                    obj.durantionIDField =  bi2de(verfArray(currentindex:currentindex+15),'left-msb');
                    currentindex = currentindex+16;
                    obj.address1Field =  bi2de(verfArray(currentindex:currentindex+47),'left-msb');
                    currentindex = currentindex + 48;
                    if  (obj.typeField ~= obj.CONTROLTYPE)  || (obj.subtypeField ~= obj.ACKSUBTYPE && obj.subtypeField ~= obj.CTSSUBTYPE)
                        obj.address2Field = bi2de(verfArray(currentindex:currentindex+47),'left-msb');
                        currentindex = currentindex + 48;
                    end
                    if  (obj.typeField == obj.MANAGEMENTTYPE || obj.typeField == obj.DATATYPE)
                        obj.address3Field = bi2de(verfArray(currentindex:currentindex+47),'left-msb');
                        currentindex = currentindex + 48;
                    end
                    status = obj.decodeSequenceControlField(verfArray(currentindex:currentindex+15));
                    currentindex = currentindex+16;
                    if status
                        if (obj.toDSField == 1 && obj.fromDSField == 1)
                            obj.address4Field = bi2de(verfArray(currentindex:currentindex+47),'left-msb');
                            currentindex = currentindex + 48;
                        end
                        if( obj.typeField == obj.DATATYPE)
                            
                            if(obj.subtypeField >= obj.QOSDATA && obj.subtypeField <= obj.QOSNULL)
                                status = obj.decodeQOScontrolField((verfArray(currentindex:currentindex+15)));
                                currentindex = currentindex+16;
                                if ~status
                                    status = 0;
                                    msg = 'error QOS field';
                                    return;
                                end
                            end
                            
                            
                            if (sizeInput >  currentindex)
                                obj.data = verfArray(currentindex:end);
                            end
                             
                        end
                        msg = 'success';
                    else
                        status = 0;
%                          msg = 'error decoding Sequence Control';
                        msg='errSqCo';
                        return;
                    end
                else
%                     msg = 'error decoding Frame Control Field';
                    msg='errConF';
                    status = 0;
                    return;
                end
            else
                  msg = 'CRC Err';
                    status = 0;
                    return;
            end
        end
    end
    
    
end



