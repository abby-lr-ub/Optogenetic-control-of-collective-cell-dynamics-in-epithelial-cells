function Segmentation = CZMBI_Cellpose( MBI, Frames, Channelname )
% do the Cellpose for all positions/blocks in MPI
% ChannelName is the channel to be Cellpose'd (can give several options)


	disp("--- Cellpose starting: " + MBI.ExperimentName +" ---");
	% the cellpose model
	CellPose = cellpose(Model="cyto2"); % uses a typical diameter of 30
	disp("Cellpose model loaded.");

	% update progress bar
	TotalFrames = length([MBI.Positions.Time]);
	framenr = 0;
	hw = waitbar2(0);

	if ~exist("Channelname","var") || isempty(Channelname)
		if ~isempty(MBI.Channels.DNA)
			Channelname = MBI.Channels.DNA;
		elseif ~isempty(MBI.Channels.Cells)
			Channelname = MBI.Channels.Cells;
		elseif ~isempty(MBI.Channels.Membrane)
			Channelname = MBI.Channels.Membrane;
		end
		if isempty(Channelname)
			warning("no Cellpose channel identified. Aborting Cellpose.");
			return;
		end
	end

	
	TypicalCellDiameter = 16;
	disp("TypicalCellDiameter = "+TypicalCellDiameter );
	
	for p=1:length(MBI.Positions)
		disp("Position "+p);
		tic;
	
		if ~exist("Frames","var") || isempty(Frames)
			Frames = 1:length(MBI.Positions(p).Time);
		end
	
		% load DNA channel(s)
		for c = 1:length(Channelname)
			ImageData(:,:,:,c)			= MBI_Load_Pos_Channel_Zproject( MBI, p, Channelname, [], Frames );
		end
		
		% if it is more than 1 channel, take the average of them!: (eg. for
		% the MCF-10A data with green/red nuclei)
		ImageData = uint8(squeeze(mean(ImageData, 4)));
		
		%ImageData = imgaussfilt( ImageData, 5);
			
		% we are now rescaling the images to fit this typical diameter (runs
		% much faster in total). Our actual nuclei are about 12microns diameter
		Rescaling		= CellPose.DetectableCellDiameter/TypicalCellDiameter * MBI.MuPerPx; 
		ScaleToMicrons	= MBI.MuPerPx / Rescaling;
	
		tic
		for t=1:length(Frames)
			im	= imresize( ImageData(:,:,t), Rescaling );
			
            % Segment!:
            L	= uint16(segmentCells2D( CellPose, im ));

            % get the segment properties
			Props = regionprops('table', L, "Centroid", "EquivDiameter", "MajorAxisLength", "MinorAxisLength", "Orientation");
			
			% scale values to micrometers (except Orientation ofc)\
            if ~isempty(Props.Centroid)
			    Props.Centroid			= Props.Centroid*ScaleToMicrons - (MBI.Positions(p).ContourSize_Mu'/2);
            end
			Props.MajorAxisLength	= Props.MajorAxisLength*ScaleToMicrons;
			Props.MinorAxisLength	= Props.MinorAxisLength*ScaleToMicrons;
			Props.EquivDiameter		= Props.EquivDiameter*ScaleToMicrons;
			Props.AR				= Props.MajorAxisLength./Props.MinorAxisLength;
	
			Segmentation{p}.NumberOfCells(t)	= size(Props,1);
			Segmentation{p}.AreaFraction(t)		= sum(~(~L(:))) / numel(L);
			Segmentation{p}.Props{t}			= Props;

			% also save the label matrix itself?
			LabelMatrix(:,:,t)			= L;
			

			% end / update waitbar
			framenr = framenr + 1;
			waitbar2(framenr/TotalFrames, hw);

			[gx,gy] = gradient(double(L));
			RGB = cat(3, imadjust(im), imadjust(im), imadjust(im));
			L((gx.^2+gy.^2)==0) = 0;
			L = imdilate(L>0, strel("disk", 2, 4));
			RGB(:, :, 1) = uint8(L)*255;
			% export debug plot to be able to check the quality later on!
			if ~exist(fullfile(CZMBI_AnalysisSubfolder(MBI), "Segmentation"), 'dir')
				mkdir( fullfile(CZMBI_AnalysisSubfolder(MBI), "Segmentation") );
			end
			FileName = CZMBI_File( MBI, "Segmentation"+filesep+"Pos" + num2str(p, "%02d") + "_t" + num2str(t, "%03d") + ".png" );
			imwrite( RGB, FileName )

			% debug plot
			if t==1 || t==length(Frames)
				figure(100+p);
				imshow(RGB);
				title( "Pos " + p + ", t=" + t + ": Fluo/Segmentation overlay");
			end
			
		end % of iteration over frames


		Segmentation{p}.CellDensity_per_mm2 = Segmentation{p}.NumberOfCells / prod(MBI.Positions(p).ContourSize_Mu/1000);
		waitbar2(framenr/TotalFrames, hw);

		toc
	
		disp( "Stats for NumberOfCells: " + Segmentation{p}.NumberOfCells(1));
		disp( "Stats for AreaFraction: " + Segmentation{p}.AreaFraction(1));
		disp( "Stats for CellDensity_per_mm2: " + round(Segmentation{p}.CellDensity_per_mm2(1)) );
		disp( "Stats for EquivDiameter:" );
		stats(Segmentation{p}.Props{1}.EquivDiameter');
		disp( "Stats for AR:" );
		stats(Segmentation{p}.Props{1}.AR');

		% save LabelMatrix per position (else too big!):
		FileName = CZMBI_File( MBI, "Segmentation"+filesep+"LabelMatrix_Pos" + num2str(p, "%02d") );
		save( FileName, "LabelMatrix");

	end
	close(hw);

	disp("--- Cellpose done: " + MBI.ExperimentName +" ---");	
	save( CZMBI_File(MBI, "Segmentation"), "Segmentation");
end
