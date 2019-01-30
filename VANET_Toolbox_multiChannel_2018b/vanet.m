function varargout = vanet(varargin)
% vanet MATLAB code for vanet.fig
%      vanet, by itself, creates a new vanet or raises the existing
%      singleton*.
%
%      H = vanet returns the handle to a new vanet or the handle to
%      the existing singleton*.
%
%      vanet('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in vanet.M with the given input arguments.
%
%      vanet('Property','Value',...) creates a new vanet or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before vanet_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to vanet_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help vanet

% Last Modified by GUIDE v2.5 20-Feb-2018 14:38:25

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @vanet_OpeningFcn, ...
                   'gui_OutputFcn',  @vanet_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before vanet is made visible.
function vanet_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to vanet (see VARARGIN)

% Choose default command line output for vanet
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes vanet wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = vanet_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in errBar.
function errBar_Callback(hObject, eventdata, handles)
% hObject    handle to errBar (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of errBar



function minNumVehicles_Callback(hObject, eventdata, handles)
% hObject    handle to minNumVehicles (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of minNumVehicles as text
%        str2double(get(hObject,'String')) returns contents of minNumVehicles as a double


% --- Executes during object creation, after setting all properties.
function minNumVehicles_CreateFcn(hObject, eventdata, handles)
% hObject    handle to minNumVehicles (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in roadType.
function roadType_Callback(hObject, eventdata, handles)
% hObject    handle to roadType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns roadType contents as cell array
%        contents{get(hObject,'Value')} returns selected item from roadType


% --- Executes during object creation, after setting all properties.
function roadType_CreateFcn(hObject, eventdata, handles)
% hObject    handle to roadType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in runButton.
function runButton_Callback(hObject, eventdata, handles)
% hObject    handle to runButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    clc;
    simTime=str2num(get(handles.simTime,'String'));
%     
    roadTypeOpt=get(handles.roadType,'String');
    roadTypeIdx=get(handles.roadType,'Value');
    roadType=char(roadTypeOpt(roadTypeIdx,:));
    
    
    switch roadType
        case '1 lane 1 direction'
            roadtype='11';
        case '2 lanes 1 direction'
            roadtype='21';
        case '2 lanes 2 directions'
            roadtype='22';
        case '4 lanes 2 directions'
            roadtype='42';
        case 'crossing with traffic light'
            roadtype='44';
    end
    
    multiNumVehicles=get(handles.multiVehilcleNum,'Value');
    
    if multiNumVehicles
        minVehicleNum=str2double(get(handles.minNumVehicles,'String'));
        maxVehicleNum=str2double(get(handles.maxNumVehicles,'String'));
        gap=str2double(get(handles.gap,'String'));
    else
        gap=1;
        minVehicleNum=str2double(get(handles.numVehicles,'String'));
        maxVehicleNum=minVehicleNum;
    end   
    mapUI=get(handles.mapUI,'Value');
    errBar=get(handles.errBar,'Value');
    
    macTXT=get(handles.macTXT,'Value');        
    if macTXT==0
        macTXT='off';
    else
        macTXT='on';
    end    
    
    appTXT=get(handles.appTXT,'Value');
    if appTXT==0
        appTXT='off';
    else
        appTXT='on';        
    end
    
    simRound=str2double(get(handles.simRound,'String'));
        
    fcn_runModel(simTime,roadtype,minVehicleNum,maxVehicleNum,gap,simRound,errBar,macTXT,appTXT,mapUI)
%     




function maxNumVehicles_Callback(hObject, eventdata, handles)
% hObject    handle to maxNumVehicles (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of maxNumVehicles as text
%        str2double(get(hObject,'String')) returns contents of maxNumVehicles as a double


% --- Executes during object creation, after setting all properties.
function maxNumVehicles_CreateFcn(hObject, eventdata, handles)
% hObject    handle to maxNumVehicles (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function simTime_Callback(hObject, eventdata, handles)
% hObject    handle to simTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of simTime as text
%        str2double(get(hObject,'String')) returns contents of simTime as a double


% --- Executes during object creation, after setting all properties.
function simTime_CreateFcn(hObject, eventdata, handles)
% hObject    handle to simTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in multiVehilcleNum.
function multiVehilcleNum_Callback(hObject, eventdata, handles)
% hObject    handle to multiVehilcleNum (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of multiVehilcleNum



function numVehicles_Callback(hObject, eventdata, handles)
% hObject    handle to numVehicles (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of numVehicles as text
%        str2double(get(hObject,'String')) returns contents of numVehicles as a double


% --- Executes during object creation, after setting all properties.
function numVehicles_CreateFcn(hObject, eventdata, handles)
% hObject    handle to numVehicles (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function gap_Callback(hObject, eventdata, handles)
% hObject    handle to gap (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of gap as text
%        str2double(get(hObject,'String')) returns contents of gap as a double


% --- Executes during object creation, after setting all properties.
function gap_CreateFcn(hObject, eventdata, handles)
% hObject    handle to gap (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in mapUI.
function mapUI_Callback(hObject, eventdata, handles)
% hObject    handle to mapUI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of mapUI



function simRound_Callback(hObject, eventdata, handles)
% hObject    handle to simRound (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of simRound as text
%        str2double(get(hObject,'String')) returns contents of simRound as a double


% --- Executes during object creation, after setting all properties.
function simRound_CreateFcn(hObject, eventdata, handles)
% hObject    handle to simRound (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in macTXT.
function macTXT_Callback(hObject, eventdata, handles)
% hObject    handle to macTXT (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of macTXT

% --- Executes on button press in appTXT.
function appTXT_Callback(hObject, eventdata, handles)
% hObject    handle to appTXT (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of appTXT
