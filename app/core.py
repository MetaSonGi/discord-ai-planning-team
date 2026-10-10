import asyncio
import json
from pathlib import Path

ROLES = {
    '기획자': '고객의 문제, 대상 사용자, 차별점, MVP를 제안한다.',
    '개발자': '구현 가능성, 아키텍처, 데이터 구조, 개발 비용과 제약을 검토한다.',
    '마케터': '고객 확보, 포지셔닝, 수익 모델과 검증 실험을 제안한다.',
    '비평가': '가정의 허점, 실패 조건, 과장과 검증되지 않은 사실을 지적한다.',
}


def chunks(text, size=1800):
    return [text[i:i + size] for i in range(0, len(text), size)]


def save(root, job):
    root = Path(root)
    root.mkdir(parents=True, exist_ok=True)
    target = root / (job['id'] + '.json')
    tmp = target.with_suffix('.tmp')
    tmp.write_text(json.dumps(job, ensure_ascii=False, indent=2), encoding='utf-8')
    tmp.replace(target)


STAGE_NOTICES = {
    '독립 제안': '**[1/3] 독립 제안** · 기획자·개발자·마케터·비평가가 각자 의견을 작성 중입니다.',
    '상호 검토': '**[2/3] 상호 검토** · 서로의 의견을 읽고 반박·보완하는 중입니다.',
    'PM 종합': '**[3/3] PM 종합** · 총괄 PM이 기획서(PRD)를 작성 중입니다. 가장 오래 걸리는 단계입니다.',
}


async def meeting(topic, ask, emit, checkpoint, announce=None):
    """9 logical calls: 4 independent proposals, 4 peer reviews, 1 PM synthesis.

    발언은 완성되는 즉시 emit한다. announce가 있으면 단계 시작마다 진행 알림을 보낸다.
    """
    transcript = []
    # 병렬 발언이 동시에 끝나도 긴 발언의 분할 메시지가 서로 섞이지 않게 한다
    emit_lock = asyncio.Lock()
    for stage in ('독립 제안', '상호 검토'):
        if announce:
            await announce(STAGE_NOTICES[stage])
        # 같은 단계의 다른 발언은 보지 않도록 단계 시작 시점의 기록만 전달한다
        context = json.dumps(transcript, ensure_ascii=False)
        async def turn(role):
            prompt = json.dumps({'topic': topic, 'stage': stage, 'previous': context}, ensure_ascii=False)
            text = await ask(role, ROLES[role], prompt)
            item = {'role': role, 'stage': stage, 'text': text}
            async with emit_lock:
                transcript.append(item)
                checkpoint(transcript)
                await emit(f"**{role}** · {stage}\n{text}")
        await asyncio.gather(*(turn(role) for role in ROLES))
    if announce:
        await announce(STAGE_NOTICES['PM 종합'])
    final = await ask('총괄 PM',
        '의견을 종합하고 선택 근거와 이견을 명시한다. Markdown PRD를 작성한다. '
        '문제/고객/해결책/MVP/제외범위/아키텍처/데이터/성공지표/검증실험/'
        '4주 일정/비용 가정/위험/사용자에게 필요한 결정 항목을 포함한다.',
        json.dumps({'topic': topic, 'transcript': transcript}, ensure_ascii=False))
    return transcript, final
