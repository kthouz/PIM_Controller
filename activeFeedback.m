%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This is an application for Belousov-Zhabontisky (BZ) experiments using programmable illumination microscope.     %
% After setting up a sample of capillaries filled with BZ drops, this application allows the user to select        %
% a number of regions to illuminated. Then, the user can select each region and assign a specific light intensity  %
% to be illuminated on that region and for how long it should be illuminated                                       %
% When the initial set up is done, the user can project light as programmed and record images to be analyzed later %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function activeFeedback
clear all
close all
clc

% initialize the GUI
h.fig.Visible = 'on';
% define global variables
global camObj camCmd recCmd pts blank shpInsert height width outDevice ...
    nROIs nCaps delay intensity opacity nshifts

intensity = .2;     % initial light intensity to be projected
opacity = 1;        % maximum opacity
camCmd = 0;         % command to be sent to the camera {0:off,1:on}
%project a black screen
outDevice = 2;      % define projector port number

% initiate java objects
ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
gds = ge.getScreenDevices();

% get size of the screen
height = gds(outDevice).getDisplayMode().getHeight();
width = gds(outDevice).getDisplayMode().getWidth();
% initliaze an RGB blank image
blank = zeros(height,width,3); 

fullscreen(blank,outDevice);
h.fig = figure('Visible','on','Position',[360,160,1200,550],'Name','PIM Control',...
            'MenuBar','none','NumberTitle','Off');

% define buttons. Each button is linked to a callback function which executes an action
h.openCam_button = uicontrol(h.fig,'Style','toggle','String','OPEN/CLOSE CAM',...
            'Position',[20,510,100,30],'Callback',@openCloseCam_callback);
h.snapshot_button = uicontrol(h.fig,'Style','pushbutton','String','SNAPSHOT',...
            'Position',[120,510,100,30],'Callback',@snapshot_callback);
h.recVid_button = uicontrol('Style','toggle','String','RECORD',...
            'Position',[220,140,100,60],'Callback',@recVid_callback);
h.selectROIs_button = uicontrol(h.fig,'Style','pushbutton','String','SELECT ROI',...
            'Position',[220,510,100,30],'Callback',@selectROIs_callback);
h.project_button = uicontrol(h.fig,'Style','toggle','String','PROJECT',...
            'Position',[220,480,100,30],'Callback',@project_callback);
h.align_button = uicontrol(h.fig,'Style','pushbutton','String','FIELD ALIGN',...
            'Position',[20,480,100,30],'Callback',@align_callback);
h.moveROI_button = uicontrol(h.fig,'Style','pushbutton','String','MOVE ROIs',...
            'Position',[120,480,100,30],'Callback',@moveROI_callback);
h.quit_button = uicontrol(h.fig,'Style','pushbutton','String','QUIT',...
            'Position',[20,140,100,56], 'Callback',@quit_callback);
h.shifts = uitable('Position',[20,200,300,280],'ColumnName',cnames',...
            'ColumnFormat',cformat,'ColumnEditable',ceditable,'RowName',rnames,...
            'Data',tdata,'CellEditCallback',@moveROI_callback);
set(h.quit_button,'Backgroundcolor','y');       % set quit_button background color to yellow
h.ax = axes('Parent',h.fig,'Position',[0.29 0.225 0.64 0.7],'Units','normalized');      % obtain axes object
        
% construct the default table to hold coordinates of regions of interest (ROI) and light intensity to be projected on each of the ROIs
nROIs = 35;     % default number of ROIs
nCaps = 10;     % default number of capillaries
[cnames rnames ceditable cformat tdata] = tSettings(nROIs,nCaps);

            
function openCloseCam_callback(source,eventdata)
    % This a callback function linked to openCam_button
    % it opens the camera if the value of source is 1 and closes it otherwise
    clc
    camCmd=get(source,'Value');     % read source value
    openCloseCam(camCmd);           % send source value to openCloseCam
end

function snapshot_callback(source,eventdata)
    % This method take a snapshot from the preview camer screen
    clc
    if camCmd == 0
        openCloseCam(1)
        img = getsnapshot(camObj);
        openCloseCam(0);
        camCmd = 0;
    else
        img = getsnapshot(camObj);
    end
    imshow(img)
    if ~ exist('Temp')
        mkdir('Temp')
    end
    
    nlen = length(ls('Temp'));
    imwrite(img,fullfile('Temp/',['test_img_',num2str(nlen+1),'.jpg']));
    size(img)
end

function recVid_callback(source,eventdata)
    recCmd = get(source,'Value');
    imgs = cell(1000,1);
    i = 1;
    init = 0;
    if recCmd == 1
        clc
        set(source,'Backgroundcolor','r');
        answer = inputdlg({'Project Name:','Delay (s):'},'',2,{date,'1'});
        delay = str2num(answer{2});
        mkdir(fullfile('OutputFiles',answer{1}));
        
        %set initial frames number
        init = inputdlg('Initial Sync. # Frames:','',1,{'0'});
        init = round(str2num(init{1}));
        
        tot_frames = inputdlg('total # Frames:','',1,{'0'});
        tot_frames = round(str2num(tot_frames{1}));
            
        if init > 0
            factor = intensity;
            fullscreen(imresize(mean(factor)*ones(size(blank)),[height width]),outDevice);
            %fullscreen(imresize(blank,[height width]),outDevice);
        end
        
        if camCmd == 0
            camCmd = 1;
           openCloseCam(1)
        end
    else
        set(source,'Backgroundcolor','default');
        if camCmd == 0
            camCmd = 0;
            openCloseCam(0)
        end
    end
    t = clock;
    while recCmd
        if i >= init%round(str2num(answer{1}))
            H = clone(shpInsert);
            % build intensity vector: 4 regions to be selected
            intensity = nshifts(1:nROIs,3)';
            H.CustomFillColor = intensity;%[0.75, 0.75, 0.75, 0.75];
            projImg = step(H,blank',pts');
            fullscreen(imresize(flipdim(projImg',1),[768,1024]),2)
        end
        
        
        frame = getsnapshot(camObj);
        imshow(frame)
        dt = clock-t;
        dt = dt(4)*3600+dt(5)*60+round(dt(6));
        imwrite(frame,fullfile('OutputFiles',answer{1},strcat(sprintf('%05d',i),'.jpg')));
        fprintf(fullfile('OutputFiles',answer{1},strcat(sprintf('%05d',i),'_at_',num2str(dt))));
        fprintf('\n');
        i = i+1;
        pause(delay)
        
        if i >= tot_frames
            fprintf(['Done recording ' num2str(i) ' frames']);
            recCmd = 0;
            %set(source,0);
        end
    end
    fullscreen(imresize(blank,[height,width]),outDevice);
    %save parameters to disk
    readme = struct;
    readme.delay = delay;
    readme.intensity = intensity;
    save(fullfile('OutputFiles',answer{1},'readme.mat'),'readme');
end

function selectROIs_callback(source,eventdata)
    %%%This method pops up a window to input the number of ROI and then
    %%%give the user the chance to select those ROIS
    clc
    %Set and select ROIs
    n = inputdlg('Enter number of ROIs','',1,{'1'});
    n = str2num(n{1});
    nROIs = n;
    pts = zeros(n,8);
    if camCmd == 0
        openCloseCam(1)
    end
    for i = 1:n
        img = getsnapshot(camObj);
        imshow(img);
        title(['Select ROI ' num2str(i) ':']);
        [~,~,bw,xi,yi] = roipoly;
        for j = 1:length(xi)-1
            pts(i,1+(j-1)*2) = xi(j);
            pts(i,2+(j-1)*2) = yi(j);
        end
        blank = zeros(size(img));
    end
    pts = int32(pts);
    H = vision.ShapeInserter('Shape','Polygons','Fill',logical(1),...
        'Opacity',opacity,'FillColor','Custom','CustomFillColor',intensity);
    %size(img)
    J = step(H,img',pts');
    imshow(J');
    shpInsert= clone(H);
    if camCmd == 0
        openCloseCam(0);
    end
end

    function project_callback(source,eventdata)
        %%%This method allows the user to start running the experiment
        %%% Overlay ROIs to the image from cam
        %%% Project the ROIs image with a black background
        %%% save images with at a programmable frame rate
        clc
        startCmd = get(source,'Value');
        
        nshifts = get(h.shifts,'Data');
        %display(nshifts(1:nROIs,3))
        intensity = nshifts(1:nROIs,3)';
        if startCmd == 1
            set(source,'Backgroundcolor','r');
            H = clone(shpInsert);
            H.Fill = logical(1);
            H.FillColorSource = 'Property';
            % build intensity vector: 4 regions to be selected
            H.CustomFillColor = intensity;%[0.75, 0.75, .75, .75];
            
            projImg = step(H,blank',pts');
            fullscreen(imresize(flipdim(projImg',1),[768,1024]),2);
        else
            set(source,'Backgroundcolor','default');
            fullscreen(imresize(blank,[768,1024]),2)
        end
    end

    function moveROI_callback(source,eventdata)
        %%%This method allows the user to shift each ROI by a specified x,y
        nshifts = get(h.shifts,'Data');
        nshifts(size(pts,1)+1:end,:) = [];
        for i = 1:size(pts,1)
            pts(i,[1,3,5,7]) = pts(i,[1,3,5,7])+nshifts(i,1);
            pts(i,[2,4,6,8]) = pts(i,[2,4,6,8])+nshifts(i,2);
            %for j = 1:round(size(pts,2)/2)
            %    pts(i,1+(1-j)*2) = pts(i,1+(1-j)*2)+nshifts(i,1);
            %    pts(i,2+(1-j)*2) = pts(i,2+(1-j)*2)+nshifts(i,2);
            %end
        end
        default_vals = zeros(size(nshifts));
        default_vals(:,3) = nshifts(:,3);
        set(h.shifts,'Data',default_vals);
        H = clone(shpInsert);
        % build intensity vector: 4 regions to be selected
        H.CustomFillColor = intensity;%[0.1, 0.1, 1, 1];
        projImg = step(H,blank',pts');
        
        fullscreen(imresize(flipdim(projImg',1),[768,1024]),2);
        
    end

    function quit_callback(source,eventdata)
        openCloseCam(0)
        camCmd = 0;
        closescreen
        close all
    end

    function align_callback(source,eventdata)
        %%%This function aligns the entire fields of interest
        answer = inputdlg({'xShif (lower x->Left):','yShift (low y->Upper):'},'shift values',2,{'0','0'});
        data = [int32(round(str2double(answer{1}))),int32(round(str2double(answer{2})))];
        for i =1:round(size(pts,2)/2)
            pts(:,1+(i-1)*2) = pts(:,1+(i-1)*2)+data(1);
            pts(:,2+(i-1)*2) = pts(:,2+(i-1)*2)+data(2);
        end
        H = clone(shpInsert);
        projImg = step(H,blank',pts');
        fullscreen(imresize(flipdim(projImg',1),[768,1024]),2);
    end

    function callibrate_light(source,eventdata)
        % project fullscreen images at different light intensities
        % for each projected image, record:
        % - read image
        % - mean of pixel values in that image
        % - deviations from the mean
        % - fit it to a function and save fitting parameters
        fprintf('Callibrating light  ')
        setIntensities = double(0:.05:1);
        for i = 1:length(setIntensities)
            fprintf('.')
            fullscreen(imresize(blank,[768,1024]),2)
            pause(1)
        
%             startCmd = get(source,'Value');
%             nshifts = get(h.shifts,'Data');
%             %display(nshifts(1:nROIs,3))
%             intensity = nshifts(1:nROIs,3)';
%             if startCmd == 1
%                 set(source,'Backgroundcolor','r');
%                 H = clone(shpInsert);
%                 H.Fill = logical(1);
%                 H.FillColorSource = 'Property';
%                 % build intensity vector: 4 regions to be selected
%                 H.CustomFillColor = intensity;%[0.75, 0.75, .75, .75];
% 
%                 projImg = step(H,blank',pts');
%                 fullscreen(imresize(flipdim(projImg',1),[768,1024]),2);
%             else
%                 set(source,'Backgroundcolor','default');
%                 fullscreen(imresize(blank,[768,1024]),2)
%             end
        end
        set(source,'Backgroundcolor','default');
        fullscreen(imresize(blank,[768,1024]),2)
    end
    
%%% This part contains all functions which are not callbacks but which are
%%% used in callback functions
    function openCloseCam(val)
    %%This function open the camera if val is 1
        if val == 1
            %info = imaqhwinfo('dcam');
            %resolution = info.DeviceInfo.SupportedFormats(end-1);
            camObj = videoinput('dcam',1,'F7_Y8_640x512_mode3');
            src_camObj = getselectedsource(camObj);
            get(src_camObj);
            preview(camObj);
        else
            delete(camObj);
            warning off
        end
    end
    
    
    function [cnames rnames ceditable cformat tdata] = tSettings(n,m)
        %%%This function constructs the defaults settings of the table
        %n is the number of ROIs
        %m is the number of capillaries
        cnames = {'xShift','yShift','intensity'};
        rnames = {};
        capnames={};
        for i =1:n
            rnames{i} = ['ROI_' num2str(i)];
        end
        for i=1:m
            capnames{i} = num2str(i);
        end
        ceditable = [true true true];
        cformat = {'numeric', 'numeric', 'numeric'}; 
        tdata = zeros(n,3);
        tdata(:,3) = .2;
    end
end

