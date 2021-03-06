%%%-------------------------------------------------------------------
%%% @author aardvocate
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 19. Jul 2014 1:48 AM
%%%-------------------------------------------------------------------
-module(v22_reader).
-author("aardvocate").

%% API
-export([read_v22/1, parse_frame_bin/3]).

-export([
  parse_cra_content/1,
  parse_com_content/1,
  parse_equ_content/1,
  parse_etc_content/1,
  parse_geo_content/1,
  parse_ipl_content/1,
  parse_lnk_content/1,
  parse_pop_content/1
]).

-include("erlp3header.hrl").

read_v22(ID3Data) ->
  Result = read_v22_frame(ID3Data, []),
  Result.

read_v22_frame(<<FrameID:3/binary, Size:24/integer, Rest/binary>>, Frames) when FrameID =/= <<0, 0, 0>> ->
  erlog:info("Read Frame ID: ~p~n", [FrameID]),
  erlog:info("Size Of Frame: ~p~n", [Size]),
  {FrameContent, ID3Data} = split_binary(Rest, Size),
  Frame = parse_frame_bin(FrameID, Size, FrameContent),
  read_v22_frame(ID3Data, [Frame | Frames]);

read_v22_frame(_, Frames) ->
  lists:reverse([Frame || Frame <- Frames, Frame =/= not_yet_implemented]).

parse_frame_bin(<<"BUF">>, Size, <<BufferSize:24/integer, EmbeddedInfo:8/integer, NextFlagOffset:32/integer>>) ->
  {buf, [{size, Size}, {buffer_size, BufferSize}, {embedded_info, erlp3_utils:boolean_code_to_atom(EmbeddedInfo)}, {next_flag_offset, NextFlagOffset}]};

parse_frame_bin(<<"BUF">>, Size, <<BufferSize:24/integer, EmbeddedInfo:8/integer>>) ->
  {buf, [{size, Size}, {buffer_size, BufferSize}, {embedded_info, erlp3_utils:boolean_code_to_atom(EmbeddedInfo)}]};

parse_frame_bin(<<"CNT">>, Size, FrameContent) ->
  Bits = Size * 8,
  <<PlayCount:Bits/integer>> = FrameContent,
  {cnt, [{size, Size}, {counter, PlayCount}]};

parse_frame_bin(<<"COM">>, Size, FrameContent) ->
  {com, [{size, Size} | parse_com_content(FrameContent)]};

parse_frame_bin(<<"CRA">>, Size, FrameContent) ->
  {cra, [{size, Size} | parse_cra_content(FrameContent)]};

parse_frame_bin(<<"CRM">>, Size, FrameContent) ->
  {crm, [{size, Size} | parse_crm_content(FrameContent)]};

parse_frame_bin(<<"ETC">>, Size, FrameContent) ->
  {etc, [{size, Size} | parse_etc_content(FrameContent)]};

parse_frame_bin(<<"EQU">>, Size, FrameContent) ->
  {equ, [{size, Size} | parse_equ_content(FrameContent)]};

parse_frame_bin(<<"GEO">>, Size, FrameContent) ->
  {geo, [{size, Size} | parse_geo_content(FrameContent)]};

parse_frame_bin(<<"IPL">>, Size, FrameContent) ->
  {ipl, [{size, Size} | parse_ipl_content(FrameContent)]};

parse_frame_bin(<<"LNK">>, Size, FrameContent) ->
  {lnk, [{size, Size} | parse_lnk_content(FrameContent)]};

parse_frame_bin(<<"MCI">>, Size, <<TOC/binary>>) ->
  {mci, [{size, Size}, {table_of_contents, TOC}]};

parse_frame_bin(<<"MLL">>, Size, <<FBR:16/integer, BBR:24/integer, MBR:24/integer, BBD:8/integer, BMD:8/integer, DeviationInBytes:BBD/integer, DeviationInMilli:BMD/integer>>) ->
  {mll, [
    {size, Size},
    {frames_between_reference, FBR},
    {bytes_between_reference, BBR},
    {milliseconds_between_reference, MBR},
    {bit_for_bytes_deviation, BBD},
    {bits_for_milliseconds_deviation, BMD},
    {deviation_in_bytes, DeviationInBytes},
    {deviation_in_milliseconds, DeviationInMilli}
  ]};

parse_frame_bin(<<"POP">>, Size, FrameContent) ->
  {pop, [{size, Size} | parse_pop_content(FrameContent)]};

parse_frame_bin(<<"PIC">>, Size, FrameContent) ->
  {pic, [{size, Size} | parse_pic_content(FrameContent)]};

parse_frame_bin(<<"REV">>, Size, <<RL:16/integer, RR:16/integer,
RBL:8/integer, RBR:8/integer, RFLTL:8/integer, RFLTR:8/integer,
RFRTR:8/integer, RFRTL:8/integer, PLTR:8/integer, PRTL:8/integer>>) ->
  {rev, [
    {size, Size},
    {reveb_left, RL},
    {reverb_right, RR},
    {reverb_bounces_left, RBL},
    {reverb_bounces_right, RBR},
    {reverb_feedback_left_to_left, RFLTL},
    {reverb_feedback_left_to_right, RFLTR},
    {reverb_feedback_right_to_right, RFRTR},
    {reverb_feedback_right_to_left, RFRTL},
    {premix_left_to_right, PLTR},
    {premix_right_to_left, PRTL}
  ]};

parse_frame_bin(<<"RVA">>, Size, <<0:6/integer, IncL:1/integer, IncR:1/integer, Len:8/integer, RVCR:Len/integer, RVCL:Len/integer, PVR:Len/integer, PVL:Len/integer>>) ->
  {rva, [
    {size, Size},
    {inc_or_dec_right, IncR},
    {inc_or_dec_left, IncL},
    {bits_used_for_volume, Len},
    {relative_volume_change_right, RVCR},
    {relative_voilume_change_left, RVCL},
    {peak_volume_right, PVR},
    {peak_volume_left, PVL}
  ]};

parse_frame_bin(<<"SLT">>, Size, <<Enc:8/integer, Language:3/binary, TimeStampFormat:8/integer, ContentType:8/integer, Rest/binary>>) ->
  {slt, [
    {size, Size},
    {encoding, Enc},
    {language, erlp3_utils:decode_string(Language)},
    {timestamp_format, erlp3_utils:time_format_code_to_atom(TimeStampFormat)},
    {content_type, erlp3_utils:slt_content_type_code_to_atom(ContentType)},
    {content_descriptor, erlp3_utils:decode_string(Enc, Rest)}
  ]};

parse_frame_bin(<<"STC">>, Size, <<TimeStampFormat:8/integer, TempoData/binary>>) ->
  {stc, [
    {size, Size},
    {timestamp_format, erlp3_utils:time_format_code_to_atom(TimeStampFormat)},
    {tempo_data, TempoData}
  ]};

parse_frame_bin(<<$T, _T2:1/binary, _T3:1/binary>> = Header, Size, <<Enc:8/integer, Rest/binary>>) ->
  TextData = case erlp3_utils:get_null_terminated_string_from_frame(Rest) of
               {Data, _Rem} ->
                 Data;
               _ ->
                 Rest
             end,
  {erlp3_utils:header_to_atom(erlp3_utils:decode_string(Header)), [
    {size, Size},
    {encoding, Enc},
    {textstring, erlp3_utils:decode_string(Enc, TextData)}
  ]};

parse_frame_bin(<<$W, _W2:1/binary, _W3:1/binary>> = Header, Size, <<URL/binary>>) ->
  {erlp3_utils:header_to_atom(erlp3_utils:decode_string(Header)), [
    {size, Size},
    {url, erlp3_utils:decode_string(URL)}
  ]};

parse_frame_bin(<<"UFI">>, Size, FrameContent) ->
  {ufi, [{size, Size} | parse_ufi_content(FrameContent)]};

parse_frame_bin(<<"ULT">>, Size, <<Enc:8/integer, Lang:3/binary, Rest/binary>>) ->
  case erlp3_utils:get_null_terminated_string_from_frame_skip_zeros(Rest) of
    {ContentDesc, Lyrics} ->
      {ult, [
        {size, Size},
        {encoding, Enc},
        {language, erlp3_utils:decode_string(Enc, Lang)},
        {content_descriptor, erlp3_utils:decode_string(Enc, ContentDesc)},
        {lyrics_text, erlp3_utils:decode_string(Enc, Lyrics)}
      ]};
    _ ->
      invalid_bytes_detected
  end;

parse_frame_bin(_Header, _Size, _FrameContent) ->
  not_yet_implemented.

parse_ufi_content(FrameContent) ->
  case erlp3_utils:get_null_terminated_string_from_frame(FrameContent) of
    {OwnerID, Identitifer} ->
      [
        {owner_identifier, erlp3_utils:decode_string(OwnerID)},
        {identifier, Identitifer}
      ]
  end.

parse_pop_content(FrameContent) ->
  case erlp3_utils:get_null_terminated_string_from_frame(FrameContent) of
    {Email, Rest} ->
      <<Rating:8/integer, CounterBin/binary>> = Rest,
      Len = length(binary_to_list(CounterBin)) * 8,
      <<Counter:Len/integer>> = CounterBin,
      [
        {email_to_user, erlp3_utils:decode_string(Email)},
        {rating, Rating},
        {counter, Counter}
      ];
    _ ->
      invalid_bytes_detected
  end.

parse_pic_content(<<Enc:8/integer, ImageFormat:3/binary, PicType:8/integer, Rest/binary>>) ->
  case erlp3_utils:get_null_terminated_string_from_frame_skip_zeros(Rest) of
    {Description, PictureData} ->
      [
        {encoding, Enc},
        {image_format, erlp3_utils:decode_string(ImageFormat)},
        {picture_type, erlp3_utils:pic_type_code_to_atom(PicType)},
        {description, erlp3_utils:decode_string(Enc, Description)},
        {picture_data, PictureData}
      ];
    _ ->
      invalid_bytes_detected
  end.

parse_lnk_content(<<LNKEDFrame:3/binary, Rest/binary>>) ->
  LinkedFrameID = erlp3_utils:decode_string(LNKEDFrame),
  case erlp3_utils:get_null_terminated_string_from_frame_skip_zeros(Rest) of
    {URL, RestAfterURL} ->
      [
        {frame_identifier, LinkedFrameID},
        {url, erlp3_utils:decode_string(URL)},
        {additional_id_data, get_additional_id_data(RestAfterURL, [])}
      ];
    _ ->
      invalid_bytes_detected
  end.

get_additional_id_data(LinkedContent, Acc) ->
  case erlp3_utils:get_null_terminated_string_from_frame(LinkedContent) of
    {IDData, Rest} ->
      Acc2 = [erlp3_utils:decode_string(IDData) | Acc],
      get_additional_id_data(Rest, Acc2);
    _ ->
      lists:reverse(Acc)
  end.

parse_ipl_content(<<Encoding:8/integer, Involvements/binary>>) ->
  [{encoding, Encoding}, {involvements, get_ipls(Encoding, Involvements, [])}].

get_ipls(Encoding, Involvements, Acc) ->
  case erlp3_utils:get_null_terminated_string_from_frame(Involvements) of
    {Involvement, RestAfterInvolvement} ->
      case erlp3_utils:get_null_terminated_string_from_frame(RestAfterInvolvement) of
        {Involvee, Rest} ->
          Acc2 = [{involvee, erlp3_utils:decode_string(Encoding, Involvee)}, {involvement, erlp3_utils:decode_string(Encoding, Involvement)} | Acc],
          get_ipls(Encoding, Rest, Acc2);
        _ ->
          invalid_bytes_detected
      end;
    _ ->
      lists:reverse(Acc)
  end.

parse_geo_content(<<Encoding:8/integer, Rest/binary>>) ->
  case erlp3_utils:get_null_terminated_string_from_frame(Rest) of
    {MimeType, RestAfterMimeType} ->
      case erlp3_utils:get_null_terminated_string_from_frame_skip_zeros(RestAfterMimeType) of
        {Filename, RestAfterFilename} ->
          case erlp3_utils:get_null_terminated_string_from_frame_skip_zeros(RestAfterFilename) of
            {ContentDesc, EncapsulatedObject} ->
              [
                {encoding, Encoding},
                {mime_type, erlp3_utils:decode_string(0, MimeType)},
                {filename, erlp3_utils:decode_string(0, Filename)},
                {content_description, erlp3_utils:decode_string(Encoding, ContentDesc)},
                {encapsulated_object, EncapsulatedObject}
              ];
            _ ->
              invalid_bytes_detected
          end;
        _ ->
          invalid_bytes_detected
      end;
    _ ->
      invalid_bytes_detected
  end.

parse_equ_content(<<AdjBits:8/integer, IncOrDec:1, Frequency:15, Rest/binary>>) ->
  <<Adjustment:AdjBits/integer>> = Rest,
  [
    {adjustment_bits, AdjBits},
    {inc_or_dec, erlp3_utils:equ_inc_dec_code_to_atom(IncOrDec)},
    {frequency, Frequency},
    {adjustment, Adjustment}
  ].

parse_etc_content(<<TimeStampFormat:8/integer, EventCode:8/integer, TimeStamp:32/integer>>) ->
  [
    {time_stamp_format, erlp3_utils:time_format_code_to_atom(TimeStampFormat)},
    {event, erlp3_utils:etc_event_code_to_atom(EventCode)},
    {timestamp, TimeStamp}
  ].

parse_crm_content(FrameContent) ->
  case erlp3_utils:get_null_terminated_string_from_frame_skip_zeros(FrameContent) of
    {OwnerID, Rem} ->
      case erlp3_utils:get_null_terminated_string_from_frame_skip_zeros(Rem) of
        {ConExp, EncryptedData} ->
          [
            {owner_id, erlp3_utils:decode_string(OwnerID)},
            {content_explanation, erlp3_utils:decode_string(ConExp)},
            {encrypted_data, EncryptedData}
          ];
        _ ->
          invalid_bytes_detected
      end;
    _ ->
      invalid_bytes_detected
  end.

parse_cra_content(FrameContent) ->
  case erlp3_utils:get_null_terminated_string_from_frame_skip_zeros(FrameContent) of
    {OwnerID, Rest} ->
      <<PreviewStart:16/integer, PreviewLength:16/integer, EncryptionInfo/binary>> = Rest,
      [
        {owner_id, erlp3_utils:decode_string(OwnerID)},
        {preview_start, PreviewStart},
        {preview_length, PreviewLength},
        {encryption_info, EncryptionInfo}
      ];
    _ ->
      invalid_bytes_detected
  end.

parse_com_content(<<Enc:8/integer, Language:3/binary, Rest/binary>>) ->
  case erlp3_utils:get_null_terminated_string_from_frame_skip_zeros(Rest) of
    {ShortDesc, Comment} ->
      [
        {language, erlp3_utils:decode_string(Enc, Language)},
        {short_description, erlp3_utils:decode_string(Enc, ShortDesc)},
        {comment, erlp3_utils:decode_string(Enc, Comment)}
      ];
    _ ->
      invalid_bytes_detected
  end.