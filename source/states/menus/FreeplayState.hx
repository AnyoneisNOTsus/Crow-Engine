package states.menus;

import music.Song;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;
import flixel.util.FlxSort;
import states.menus.MainMenuState;
import weeks.ScoreContainer;
import weeks.SongHandler;
import objects.HealthIcon;
import utils.CacheManager;

using utils.Tools;

class FreeplayState extends MusicBeatState
{
	private var songs:Array<SongMetadata> = [];

	public var background:FlxSprite;

	public var scoreBG:FlxSprite;
	public var scoreText:FlxText;
	public var diffText:FlxText;

	public var songList:FlxTypedGroup<Alphabet>;
	public var iconArray:Array<HealthIcon> = [];

	private static var curSelected:Int = 0;
	private static var curDifficulty:Int = Std.int(Math.max(0, SongHandler.PLACEHOLDER_DIFF.indexOf(SongHandler.defaultDifficulty)));

	private static var savedScore:Float = 0.0;
	private static var savedAccuracy:Float = 0.0;

	private static var lerpingScore:Float = 0.0;
	private static var lerpingAccuracy:Float = 0.0;

	override public function create()
	{
		CacheManager.freeMemory(BITMAP, true);

		background = new FlxSprite(0, 0).loadGraphic(Paths.image("menus/freeplayBG"));
		background.scale.set(1.1, 1.1);
		background.screenCenter();
		background.scrollFactor.set();
		background.antialiasing = Settings.getPref('antialiasing', true);
		add(background);

		scoreBG = new FlxSprite().makeGraphic(Std.int(FlxG.width * 0.35), 75, FlxColor.BLACK);
		scoreBG.alpha = 0.6;
		scoreBG.x = FlxG.width - scoreBG.width;
		scoreBG.antialiasing = Settings.getPref('antialiasing', true);

		scoreText = new FlxText(0, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE);
		scoreText.text = 'PERSONAL BEST: ${Math.floor(savedScore)} (${Tools.formatAccuracy(savedAccuracy)}%)';
		scoreText.x = FlxG.width - scoreText.width - 8;
		// scoreText.centerOverlay(scoreBG, X); might come in handy
		scoreText.antialiasing = Settings.getPref('antialiasing', true);

		diffText = new FlxText(0, scoreText.y + 35, FlxG.width - scoreText.x, "", 26);
		diffText.setFormat(Paths.font("vcr.ttf"), 26, FlxColor.WHITE, CENTER);
		diffText.antialiasing = Settings.getPref('antialiasing', true);
		diffText.centerOverlay(scoreBG, X);

		// bro using them map.keys() is unordered i have to manually sort them AAAAA
		var weekHolder:Array<{index:Int, week:String}> = [];

		for (week in SongHandler.songs['Base_Game'].keys())
		{
			weekHolder.push({index: SongHandler.songs['Base_Game'][week].index, week: week});
		}

		weekHolder.sort(function(a, b)
		{
			return FlxSort.byValues(FlxSort.ASCENDING, a.index, b.index);
		});

		songList = new FlxTypedGroup<Alphabet>();
		add(songList);

		for (week in weekHolder)
		{
			var i:Int = songList.length;

			var songsList:Array<String> = SongHandler.songs['Base_Game'][week.week].songs;

			if (i == 0)
				background.color = currentColor = SongHandler.songs['Base_Game'][week.week].color;
			for (song in songsList)
			{
				var j:Int = weekHolder.indexOf(week) + songsList.indexOf(song);

				var songObject:Alphabet = new Alphabet(0, (70 * j) + 30, song, true, false);
				songObject.isMenuItem = true;
				songObject.targetY = i + j;
				songObject.ID = Std.int(i + j);
				songList.add(songObject);

				var iconObject:HealthIcon = new HealthIcon(0, 0, SongHandler.songs['Base_Game'][week.week].icons[songsList.indexOf(song)]);
				iconObject.ID = songObject.ID;
				iconObject.sprTracker = songObject;
				iconObject.offsetTracker.set(songObject.width + 10, (songObject.height / 2) - (iconObject.height / 2));
				iconArray.push(iconObject);
				add(iconObject);

				var metaData:SongMetadata = new SongMetadata(song, Std.int(i + 1), SongHandler.songs['Base_Game'][week.week].diffs,
					SongHandler.songs['Base_Game'][week.week].color);
				// metaData.
				metaData.weekName = week.week;

				songs.push(metaData);
			}
		}

		add(scoreBG);
		add(scoreText);
		add(diffText);

		changeSelection();
		changeDiff();

		updateScore(FlxMath.MAX_VALUE_FLOAT);

		super.create();
	}

	private var currentColor:Int = 0;
	private var canPress:Bool = true;

	private static var lastPlayed:String = '';

	override public function update(elapsed:Float)
	{
		if (canPress)
		{
			if (controls.getKey('BACK', JUST_PRESSED))
			{
				canPress = false;
				MusicBeatState.switchState(new MainMenuState());
			}
			else if (controls.getKey('ACCEPT', JUST_PRESSED))
			{
				canPress = false;

				if (Song.currentSong != null)
				{
					if (lastPlayed != Song.currentSong.song)
					{
						CacheManager.clearAudio(Paths.instPath(lastPlayed));
						CacheManager.clearAudio(Paths.vocalsPath(lastPlayed));

						lastPlayed = Song.currentSong.song;
					}
				}

				Paths.currentLibrary = songs[curSelected].weekName;
				PlayState.songDiff = curDifficulty;

				FlxG.sound.music.fadeOut(0.5, 0.0);

				Song.loadSong(songs[curSelected].name.formatToReadable(), curDifficulty);

				MusicBeatState.switchState(new PlayState(), function()
				{
					Paths.inst(Song.currentSong.song);
					Paths.vocals(Song.currentSong.song);
				});
			}
			else
			{
				if (controls.getKey('UI_UP', JUST_PRESSED))
					changeSelection(-1);
				else if (controls.getKey('UI_DOWN', JUST_PRESSED))
					changeSelection(1);

				if (controls.getKey('UI_LEFT', JUST_PRESSED))
					changeDiff(-1);
				else if (controls.getKey('UI_RIGHT', JUST_PRESSED))
					changeDiff(1);
			}
		}

		updateScore(elapsed);

		background.color = FlxColor.interpolate(background.color, currentColor, FlxMath.bound(elapsed * 1.75, 0, 1));

		super.update(elapsed);
	}

	private function updateScore(elapsed:Float = 1):Void
	{
		var scoreString:String = 'PERSONAL BEST: ';

		lerpingScore = Tools.lerpBound(lerpingScore, savedScore, elapsed * 8.775);
		if (Math.abs(savedScore - lerpingScore) < 10)
			lerpingScore = savedScore;
		scoreString += (lerpingScore > 1000000) ? Tools.shorthandNumber(Math.floor(lerpingScore),
			['K', 'M', 'B']) : FlxStringUtil.formatMoney(Math.floor(lerpingScore), false);

		lerpingAccuracy = Tools.lerpBound(lerpingAccuracy, savedAccuracy, elapsed * 4.775);
		if (Math.abs(savedAccuracy - lerpingAccuracy) <= 0.05)
			lerpingAccuracy = savedAccuracy;
		scoreString += ' (${Tools.formatAccuracy(FlxMath.roundDecimal(lerpingAccuracy * 100, 2))}%)';

		scoreText.text = scoreString;
		scoreText.x = FlxMath.lerp(scoreText.x, FlxG.width - scoreText.width - 8, FlxMath.bound(elapsed * 6.775, 0, 1));

		scoreBG.x = scoreText.x - 8;
		scoreBG.setGraphicSize(Std.int(Math.max(scoreText.width + 16, (FlxG.width + 20) - scoreText.x)), Std.int(scoreBG.height));
		scoreBG.updateHitbox();

		diffText.centerOverlay(scoreBG, X);
	}

	public function changeSelection(change:Int = 0)
	{
		if (change != 0)
			FlxG.sound.play(Paths.sound('menu/scrollMenu'), 0.75);

		curSelected = FlxMath.wrap(curSelected + change, 0, songList.length - 1);

		var range:Int = 0;

		for (song in songList)
		{
			song.targetY = range - curSelected;
			range++;

			if (song.targetY == 0)
			{
				song.alpha = 1.0;
			}
			else
			{
				song.alpha = 0.6;
			}
		}

		for (i in 0...iconArray.length)
		{
			iconArray[i].alpha = 0.6;
		}

		iconArray[curSelected].alpha = 1;

		currentColor = songs[curSelected].color;

		var songResult = ScoreContainer.getSong(songs[curSelected].name.formatToReadable(), curDifficulty);

		savedScore = songResult.score;
		savedAccuracy = songResult.accuracy;
	}

	public function changeDiff(change:Int = 0)
	{
		if (change != 0)
			FlxG.sound.play(Paths.sound('menu/scrollMenu'), 0.50);

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, 2);

		diffText.text = switch (SongHandler.PLACEHOLDER_DIFF.length)
		{
			case 0:
				"";
			case 1:
				SongHandler.PLACEHOLDER_DIFF[0].toUpperCase();
			case _:
				'< ' + SongHandler.PLACEHOLDER_DIFF[curDifficulty].toUpperCase() + ' >';
		}

		diffText.centerOverlay(scoreBG, X);

		changeSelection();
	}
}

class SongMetadata
{
	public var name:String;
	public var weekName:String;
	public var week:Int;
	public var diffs:Array<String>;
	public var color:Int;

	public function new(name:String, week:Int, diffs:Array<String>, color:Int)
	{
		this.name = name;
		this.week = week;
		this.diffs = diffs;
		this.color = color;
	}
}
