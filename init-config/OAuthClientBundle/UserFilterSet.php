<?php

declare(strict_types=1);

namespace App\Crudit\Datasource\Filterset;

use Lle\CredentialBundle\Entity\Group;
use Lle\CruditBundle\Datasource\AbstractFilterSet;
use Lle\CruditBundle\Filter\FilterType\AbstractFilterType;
use Lle\CruditBundle\Filter\FilterType\BooleanFilterType;
use Lle\CruditBundle\Filter\FilterType\EntityFilterType;
use Lle\CruditBundle\Filter\FilterType\StringFilterType;

/**
 * @return array<int, AbstractFilterType>
 */
class UserFilterSet extends AbstractFilterSet
{
    public function getFilters(): array
    {
        return [
            StringFilterType::new('username'),
            StringFilterType::new('email'),
            StringFilterType::new('prenom'),
            StringFilterType::new('nom'),
            BooleanFilterType::new('actif'),
            EntityFilterType::new('profil', Group::class, 'app_crudit_group_autocomplete'),
        ];
    }

    public function getNumberDisplayed(): int
    {
        return 6;
    }
}
