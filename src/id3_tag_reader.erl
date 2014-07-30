%%%-------------------------------------------------------------------
%%% @author aardvocate
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 16. Jul 2014 2:11 PM
%%%-------------------------------------------------------------------
-module(id3_tag_reader).
-author("aardvocate").

%% API
-export([read_tag/1, read_v2_header/1]).

-include("erlp3header.hrl").

read_tag(File) ->
  case file:open(File, [read, binary, raw]) of
    {ok, S} ->
      erlog:info("Checking for V2~n"),
      {ok, IDv2Tag} = file:pread(S, 0, 3),
      IDv2TagResult = case IDv2Tag of
                        <<"ID3">> ->
                          erlog:info("Found ID3v2~n"),
                          parse_v2_tag(S);
                        _ ->
                          erlog:info("ID3v2 Not Found ~p~n", [IDv2Tag]),
                          not_found
                      end,

      erlog:info("Checking for V1~n"),
      file:position(S, {eof, -128}),

      {ok, ID3V1Tag} = file:read(S, 3),
      IDv1TagResult = case ID3V1Tag of
                        <<"TAG">> ->
                          erlog:info("Found ID3v1~n"),
                          parse_v1_tag(S);
                        _ ->
                          erlog:info("ID3v1 Not Found~n"),
                          not_found
                      end,
      file:close(S),
      {ok, [{idv1tag, IDv1TagResult}, {idv2tag, IDv2TagResult}]};
    _Error ->
      error
  end.

parse_v2_tag(FileHandle) ->
  {ok, FirstTen} = file:read(FileHandle, 10),
  {ok, Header} = read_v2_header(FirstTen),
  {ok, ExtendedHeader} = read_v2_ex_header(FileHandle, Header),
  Version = proplists:get_value(version, Header),
  V2Data = read_v2(Version, FileHandle, Header),
  [{header, Header}, {extended_header, ExtendedHeader}, {tags, V2Data}].

read_v2_header(<<"ID3", MajV:8/integer, MinV:8/integer, A:1/integer, B:1/integer,
_UnusedFlags:6, S1:8/integer, S2:8/integer, S3:8/integer, S4:8/integer>>)
  when S1 < 128, S2 < 128, S3 < 128, S4 < 128, MajV =:= 2 ->
  {Unsync, Compression} = {A, B},
  {ok, Size} = utils:synch_safe(<<S1, S2, S3, S4>>),

  {ok,
    [
      {version, {2, MajV, MinV}},
      {flags, [{unsync, Unsync}, {compression, Compression}]},
      {size, Size}
    ]
  };

read_v2_header(<<"ID3", MajV:8/integer, MinV:8/integer, A:1/integer, B:1/integer, C:1/integer,
_UnusedFlags:5, S1:8/integer, S2:8/integer, S3:8/integer, S4:8/integer>>)
  when S1 < 128, S2 < 128, S3 < 128, S4 < 128, MajV =:= 3 ->
  {Unsync, Extended, Experimental} = {A, B, C},
  {ok, Size} = utils:synch_safe(<<S1, S2, S3, S4>>),

  {ok,
    [
      {version, {2, MajV, MinV}},
      {flags, [{unsync, Unsync}, {extended, Extended}, {experimental, Experimental}]},
      {size, Size}
    ]
  };

read_v2_header(<<"ID3", MajV:8/integer, MinV:8/integer, A:1/integer, B:1/integer, C:1/integer, D:1/integer,
_UnusedFlags:4, S1:8/integer, S2:8/integer, S3:8/integer, S4:8/integer>>)
  when S1 < 128, S2 < 128, S3 < 128, S4 < 128, MajV =:= 4 ->
  {Unsync, Extended, Experimental, Footer} = {A, B, C, D},
  {ok, Size} = utils:synch_safe(<<S1, S2, S3, S4>>),

  {ok,
    [
      {version, {2, MajV, MinV}},
      {flags, [{unsync, Unsync}, {extended, Extended}, {experimental, Experimental}, {footer, Footer}]},
      {size, Size}
    ]
  };

read_v2_header(_) ->
  {error, invalid_v2_header_bytes}.

read_v2_ex_header(FileHandle, Header) ->
  Flags = proplists:get_value(flags, Header),
  ReadExtendedHeader = proplists:get_value(extended, Flags),
  {ok, if
         ReadExtendedHeader =:= 1 ->
           {ok, ID3Data} = file:read(FileHandle, proplists:get_value(size, Header)),
           <<ExSize:32/integer, ExFlagCRC:1/integer, _RemFlags:15, Rest/binary>> = ID3Data,
           ExHeader = [{extended_header_size, ExSize}, {extended_header_crc_present, ExFlagCRC} | []],
           if
             ExFlagCRC =:= 1 ->
               <<CData:32/integer, _RemIDData/binary>> = Rest,
               [{crcdata, CData} | ExHeader];
             true ->
               ExHeader
           end;
         true ->
           []
       end}.

read_v2({2, 2, _}, FileHandle, Header) ->
  erlog:info("Found Version 2.2.0~n"),
  v22_reader:read_v22(FileHandle, Header);

read_v2({2, 3, _}, FileHandle, Header) ->
  erlog:info("Found Version 2.3.0~n"),
  v23_reader:read_v23(FileHandle, Header);

read_v2({2, 4, _}, _FileHandle, _Header) ->
  erlog:info("Found Version 2.4.0~n"),
  %io:format("Header: ~p~n", [Header]),
  %io:format("Content: ~p~n", [file:read(FileHandle, 100)]),
  ok.

parse_v1_tag(_FileHandle) ->
  ok.

%%parse_v1_tag(<<$T, $A, $G, Title:30/binary, Artist:30/binary, Album:30/binary, Year:4/binary, Comment:28/binary,  0:1, Track:1, Genre:1>> = _Result) ->
%%  {ok, "ID3v1.1", #id3v1_1{tag = "ID3v1.1", title = Title, artist = Artist, album = Album, year = Year, comment = Comment, track = Track, genre = Genre}};


%%parse_v1_tag(<<$T, $A, $G, Title:30/binary, Artist:30/binary, Album:30/binary, Year:4/binary, Comment:30/binary, Genre:8>>) ->
%%  {ok, "ID3v1", #id3v1{tag = "ID3v1", title = Title, artist = Artist, album = Album, year = Year, comment = Comment, genre = Genre}}.
