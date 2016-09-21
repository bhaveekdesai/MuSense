function [] = MuSense()
%Start broadcasting server
!python server\acquisition_server.py &

%Listen to broadcasting server
hudpr = dsp.UDPReceiver('LocalIPPort',8888,'MessageDataType','int8');

%%% <3D Audio Part>

%load the HRTF
load(deblank(sprintf('%s', 'resources\HRTF.mat')));

%initialize variables
wav_left = [];
wav_right = [];
soundToPlay = [];
soundToSave = [];
%specifying which location to play
azimuth = -180;
elevation = 0;

FileReader = dsp.AudioFileReader('resources\soundset.wav', 'SamplesPerFrame', 44100,...
    'PlayCount', 1);

FilePlayer = dsp.AudioPlayer('QueueDuration', 1, 'BufferSizeSource', ...
    'Property', 'BufferSize', 11050, 'SampleRate', FileReader.SampleRate);

progress=0;
azimuth_incremental_factor=0;
% alpha_3d_trigger_threshold = 1.075; %15
% theta_3d_trigger_threshold = 1.075; %45
handle = guihandles(app);
progressBar = waitbar(0,'Meditation Level');
% hold on
% xlim([0 100])
% set(gca,'xtick',[])
% set(gca,'ytick',[])
% progress_bar = findobj(gcf,'Tag','progressBar');
%%% </3D Audio Part>

%Capture data
while exist('_trigger','file') == 2
    data = strsplit(char(step(hudpr)'), ' ');
    alpha_3d_trigger_threshold = 0.45 + get(handle.difficultyLevel, 'value'); %1.075; %15
    theta_3d_trigger_threshold = 0.75 + get(handle.difficultyLevel, 'value'); %1.075; %45
    
    
    %%Uncomment following line to print captured data
    %[THETA, ALPHA, BETA_LOW, BETA_HIGH, GAMMA]
    
    %%% <3D Audio Part>
    
    iAz = find(Theta == azimuth);
    iEl = find(Phi == elevation);
    iLoc = intersect(iAz, iEl);
    delay = delay_based_on_HRTF(iLoc);
    
    
    %get the common transfer function and the directional transfer function
    %and inverse fft to get the impulse response
    %won't need this for MARL or CIPIC - skip straight to next section
    
    %create the impulse response for the left ear from frequency response
    %this step is not necessary if the HRTF database stores the Impulse
    %repsonse
    x = real(ifft(10.^((LDTFAmp(:, iLoc)+LCTF)/20)));
    %get real cepstrum of the real sequence
    [y, tmp] = rceps(x);
    lft = tmp(1:min(length(tmp), 256));
    
    %create the impulse response for the right ear from frequency response
    %this step is not necessary if the HRTF database stores the Impulse
    %repsonse
    x = real(ifft(10.^((RDTFAmp(:, iLoc)+RCTF)/20)));
    %get real cepstrum of the real sequence
    [y, tmp] = rceps(x);
    rgt = tmp(1:min(length(tmp), 256));
    
    %add delay
    %this step is not necessary if database includes the delay as part of
    %the impulse response
    if delay <= 0
        lft = [lft' zeros(size(1:abs(delay)))];
        rgt = [zeros(size(1:abs(delay))) rgt'];
    else
        lft = [zeros(size(1:abs(delay))) lft'];
        rgt = [rgt' zeros(size(1:abs(delay)))];
    end
    
    %make sure left and right ear vectors are the same size
    npts = max(length(lft), length(rgt));
    lft = [lft zeros(size(1:320-npts))];
    rgt = [rgt zeros(size(1:320-npts))];
    
    %get the sound, make sure it's one column
    sig = step(FileReader);
    sig = sig(:,1);
    
    
    %convolve with left and right impulse responses
    wav_left = conv(lft', sig) ;
    wav_right = conv(rgt', sig);
    
    
    %create sound to play
    soundToPlay(:,1) = wav_left;
    soundToPlay(:,2) = wav_right;
    
    %play frame of data
    step(FilePlayer, soundToPlay);
    
    if (length(data) == 5)
        
        %Fetch components
        THETA = str2double(data{1});
        ALPHA = str2double(data{2});
        BETA_LOW = str2double(data{3});
        BETA_HIGH = str2double(data{4});
        GAMMA = str2double(data{5});
        
        %increment azimuth and wrap around head
        if (ALPHA >= alpha_3d_trigger_threshold && THETA >= theta_3d_trigger_threshold)
            progress = progress + 1;
        else
            progress = progress - 1;
        end
        
        if (progress < 0)
            progress = 0;
        elseif (progress >= 0 && progress < 25)
            azimuth_incremental_factor = 0;
            azimuth = -180;
        elseif (progress >= 25 && progress < 50)
            azimuth_incremental_factor = -10;
        elseif (progress >= 50 && progress < 75)
            azimuth_incremental_factor = 10;
        elseif (progress >= 75 && progress <= 100)
            azimuth_incremental_factor = -20;
        elseif (progress > 100)
            progress = 100;
        end
    end
    azimuth = azimuth + azimuth_incremental_factor;
    %         elevation = elevation + 10;
    if (azimuth > 170)
        azimuth = -180;
    end
    if (azimuth < -180)
        azimuth = 170;
    end
    
    %         clf
    %         barh(progress_bar, progress)
    
    %         drawnow
    waitbar(progress/100, progressBar);
    
    %%% </3D Audio Part>
    soundToSave = [soundToSave; soundToPlay];
    
    %     pause(1)
end
% hold off

path = ['sessions\test2.wav'];
audiowrite(path,soundToSave,44100);
end
