package;

import flixel.input.gamepad.FlxGamepad;
import openfl.Lib;
#if FEATURE_LUAMODCHART
import llua.Lua;
#end
import Controls.Control;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

class PauseSubState extends MusicBeatSubstate
{
	var grpMenuShit:FlxTypedGroup<Alphabet>;

	public static var goToOptions:Bool = false;
	public static var goBack:Bool = false;

	var pauseOG:Array<String> = ['Resume', 'Restart Song', 'Change Difficulty', 'Options', 'Exit to menu'];
	var difficultyChoices = [];

	var menuItems:Array<String> = [];

	var curSelected:Int = 0;

	public static var playingPause:Bool = false;

	var pauseMusic:FlxSound;

	var perSongOffset:FlxText;

	var offsetChanged:Bool = false;
	var startOffset:Float = PlayState.SONG.offset;

	var bg:FlxSprite;

	public function new()
	{
		Paths.clearUnusedMemory();
		super();

		if (CoolUtil.difficultyArray.length < 2)
			pauseOG.remove('Change Difficulty'); // No need to change difficulty if there is only one!

		if (FlxG.sound.music.playing)
			FlxG.sound.music.pause();

		for (i in FlxG.sound.list)
		{
			if (i.playing && i.ID != 9000)
				i.pause();
		}

		menuItems = pauseOG;

		for (i in 0...CoolUtil.difficultyArray.length)
		{
			var diff:String = '' + CoolUtil.difficultyArray[i];
			difficultyChoices.push(diff);
		}
		difficultyChoices.push('BACK');

		if (!playingPause)
		{
			playingPause = true;
			pauseMusic = new FlxSound().loadEmbedded(Paths.music('breakfast'), true, true);
			pauseMusic.volume = 0;
			pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));
			pauseMusic.ID = 9000;

			FlxG.sound.list.add(pauseMusic);
		}
		else
		{
			for (i in FlxG.sound.list)
			{
				if (i.ID == 9000) // jankiest static variable
					pauseMusic = i;
			}
		}

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var levelInfo:FlxText = new FlxText(20, 15, 0, "", 32);
		levelInfo.text += PlayState.SONG.songName.toUpperCase();
		levelInfo.scrollFactor.set();
		levelInfo.setFormat(Paths.font("vcr.ttf"), 32);
		levelInfo.updateHitbox();
		add(levelInfo);

		var levelDifficulty:FlxText = new FlxText(20, 15 + 32, 0, "", 32);
		levelDifficulty.text += CoolUtil.difficultyFromInt(PlayState.storyDifficulty).toUpperCase();
		levelDifficulty.scrollFactor.set();
		levelDifficulty.setFormat(Paths.font('vcr.ttf'), 32);
		levelDifficulty.updateHitbox();
		add(levelDifficulty);

		levelDifficulty.alpha = 0;
		levelInfo.alpha = 0;

		levelInfo.x = FlxG.width - (levelInfo.width + 20);
		levelDifficulty.x = FlxG.width - (levelDifficulty.width + 20);

		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(levelInfo, {alpha: 1, y: 20}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(levelDifficulty, {alpha: 1, y: levelDifficulty.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});

		grpMenuShit = new FlxTypedGroup<Alphabet>();
		add(grpMenuShit);

		changeSelection();

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		regenMenu();
	}

	#if !mobile
	var oldPos = FlxG.mouse.getScreenPosition();
	#end

	override function update(elapsed:Float)
	{
		// if (pauseMusic.volume < 0.5)
		// pauseMusic.volume += 0.01 * elapsed;

		super.update(elapsed);

		#if !mobile
		if (FlxG.mouse.wheel != 0)
			#if desktop
			changeSelection(-FlxG.mouse.wheel);
			#else
			if (FlxG.mouse.wheel < 0)
				changeSelection(1);
			if (FlxG.mouse.wheel > 0)
				changeSelection(-1);
			#end
		#end

		for (i in FlxG.sound.list)
		{
			if (i.playing && i.ID != 9000)
				i.pause();
		}

		if (bg.alpha > 0.6)
			bg.alpha = 0.6;
		var oldOffset:Float = 0;

		var songPath = 'assets/data/songs/${PlayState.SONG.songId}/';

		#if FEATURE_STEPMANIA
		if (PlayState.isSM && !PlayState.isStoryMode)
			songPath = PlayState.pathToSm;
		#end

		if (controls.UP_P)
		{
			changeSelection(-1);
		}
		else if (controls.DOWN_P)
		{
			changeSelection(1);
		}

		if ((controls.ACCEPT && !FlxG.keys.pressed.ALT) || FlxG.mouse.pressed)
		{
			var daSelected:String = menuItems[curSelected];

			if (menuItems == difficultyChoices)
			{
				if (menuItems.length - 1 != curSelected && difficultyChoices.contains(daSelected))
				{
					PlayState.SONG = Song.loadFromJson(PlayState.SONG.songId.toLowerCase(),
						CoolUtil.getSuffixFromDiff(CoolUtil.difficultyArray[PlayState.storyDifficulty]));
					PlayState.storyDifficulty = curSelected;
					PlayState.startTime = 0;
					MusicBeatState.resetState();
					return;
				}

				menuItems = pauseOG;
				regenMenu();
			}

			switch (daSelected)
			{
				case "Resume":
					close();
					Ratings.timingWindows = [
						FlxG.save.data.shitMs,
						FlxG.save.data.badMs,
						FlxG.save.data.goodMs,
						FlxG.save.data.sickMs,
						FlxG.save.data.marvMs
					];
					if (!PlayState.instance.speedChanged)
						PlayState.instance.scrollSpeed = (FlxG.save.data.scrollSpeed == 1 ? PlayState.SONG.speed : FlxG.save.data.scrollSpeed) * PlayState.instance.scrollMult;
					FlxTween.tween(PlayState.laneunderlay, {alpha: FlxG.save.data.laneTransparency}, 1);
					FlxTween.tween(PlayState.laneunderlayOpponent, {alpha: FlxG.save.data.laneTransparency}, 1);
					PlayStateChangeables.botPlay = FlxG.save.data.botplay;

				case "Restart Song":
					PlayState.startTime = 0;
					MusicBeatState.resetState();
				case 'Change Difficulty':
					menuItems = difficultyChoices;
					regenMenu();
				case "Options":
					goToOptions = true;
					close();
				case "BACK":
					menuItems = pauseOG;
					regenMenu();
				case "Exit to menu":
					PlayState.startTime = 0;
					if (PlayState.loadRep)
					{
						FlxG.save.data.botplay = false;
						FlxG.save.data.scrollSpeed = 1;
						FlxG.save.data.downscroll = false;
					}
					PlayState.loadRep = false;
					PlayState.stageTesting = false;
					PlayState.inDaPlay = false;
					#if FEATURE_LUAMODCHART
					if (PlayState.luaModchart != null)
					{
						PlayState.luaModchart.die();
						PlayState.luaModchart = null;
					}
					#end

					if (PlayState.isStoryMode)
					{
						GameplayCustomizeState.freeplayNoteStyle = 'normal';
						MusicBeatState.switchState(new StoryMenuState());
					}
					else if (PlayState.loadRep)
					{
						MusicBeatState.switchState(new LoadReplayState());
					}
					else
					{
						MusicBeatState.switchState(new FreeplayState());
					}
			}
		}
	}

	override function destroy()
	{
		if (!goToOptions)
		{
			pauseMusic.destroy();
			playingPause = false;
		}

		super.destroy();
	}

	private function regenMenu():Void
	{
		while (grpMenuShit.members.length > 0)
		{
			grpMenuShit.remove(grpMenuShit.members[0], true);
		}

		for (i in 0...menuItems.length)
		{
			var songText = new Alphabet(90, 320, menuItems[i], true);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpMenuShit.add(songText);
		}

		curSelected = 0;
		changeSelection();
	}

	function changeSelection(change:Int = 0):Void
	{
		curSelected += change;

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		if (curSelected < 0)
			curSelected = menuItems.length - 1;
		if (curSelected >= menuItems.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpMenuShit.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
	}
}
